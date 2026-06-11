import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:siptalk/main.dart';
import 'package:siptalk/sip/sip_account.dart';
import 'package:siptalk/sip/sip_call.dart';
import 'package:siptalk/sip/sip_controller.dart';
import 'package:siptalk/sip/sip_event.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('SipTalk home renders phone controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SipTalkApp(controller: SipControllerStub()));
    await tester.pumpAndSettle();

    expect(find.text('SipTalk'), findsOneWidget);
    expect(find.text('Dial number'), findsOneWidget);
    expect(find.text('Account not configured'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.text('Register'), findsNothing);
  });

  testWidgets('configured account registers automatically on startup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sip_profile.domain': 'pbx.example.test',
      'sip_profile.username': '2001',
      'sip_profile.transport': 'udp',
      'sip_profile.expires': '300',
      'sip_profile.destination': '2002',
    });
    FlutterSecureStorage.setMockInitialValues({
      'sip_profile.password': 'secret',
    });

    await tester.pumpWidget(SipTalkApp(controller: SipControllerStub()));
    await tester.pumpAndSettle();

    expect(find.text('Registering'), findsOneWidget);
  });

  testWidgets('incoming call opens full screen answer surface', (
    WidgetTester tester,
  ) async {
    final controller = ControllableSipController();
    await tester.pumpWidget(SipTalkApp(controller: controller));
    await tester.pumpAndSettle();

    controller.emit(
      const SipIncomingCall(
        SipCallInfo(
          id: 'call-1',
          accountId: 'default',
          state: SipCallState.incomingSip,
          remoteUri: 'sip:2002@pbx.example.test',
          displayName: '2002',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('2002'), findsOneWidget);

    await tester.tap(find.text('Answer').last);
    await tester.pumpAndSettle();

    expect(controller.answeredCallIds, contains('call-1'));
    expect(find.text('Incoming call'), findsNothing);
  });

  testWidgets('incoming call reject uses incoming call id', (
    WidgetTester tester,
  ) async {
    final controller = ControllableSipController();
    await tester.pumpWidget(SipTalkApp(controller: controller));
    await tester.pumpAndSettle();

    controller.emit(
      const SipIncomingCall(
        SipCallInfo(
          id: 'call-reject',
          accountId: 'default',
          state: SipCallState.incomingSip,
          remoteUri: 'sip:2003@pbx.example.test',
          displayName: '2003',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();

    expect(controller.rejectedCallIds, contains('call-reject'));
    expect(find.text('Incoming call'), findsNothing);
  });

  testWidgets('incoming call early connecting state keeps ringing surface', (
    WidgetTester tester,
  ) async {
    final controller = ControllableSipController();
    await tester.pumpWidget(SipTalkApp(controller: controller));
    await tester.pumpAndSettle();

    controller.emit(
      const SipIncomingCall(
        SipCallInfo(
          id: 'call-early',
          accountId: 'default',
          state: SipCallState.incomingSip,
          remoteUri: 'sip:2005@pbx.example.test',
          displayName: '2005',
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.emit(
      const SipCallStateChanged(
        SipCallInfo(
          id: 'call-early',
          accountId: 'default',
          state: SipCallState.connecting,
          remoteUri: 'sip:2005@pbx.example.test',
          displayName: '2005',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('In call'), findsNothing);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('in-call state shows timer and returns to idle when ended', (
    WidgetTester tester,
  ) async {
    final controller = ControllableSipController();
    await tester.pumpWidget(SipTalkApp(controller: controller));
    await tester.pumpAndSettle();

    controller.emit(
      const SipCallStateChanged(
        SipCallInfo(
          id: 'call-active',
          accountId: 'default',
          state: SipCallState.inCall,
          remoteUri: 'sip:2004@pbx.example.test',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('In call'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byIcon(Icons.call_end), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    controller.emit(
      const SipCallStateChanged(
        SipCallInfo(
          id: 'call-active',
          accountId: 'default',
          state: SipCallState.ended,
          remoteUri: 'sip:2004@pbx.example.test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In call'), findsNothing);
    expect(find.text('Dial number'), findsOneWidget);
  });
}

class ControllableSipController implements SipController {
  final _events = StreamController<SipEvent>.broadcast();
  final answeredCallIds = <String>[];
  final rejectedCallIds = <String>[];
  final hungUpCallIds = <String>[];

  @override
  Stream<SipEvent> get events => _events.stream;

  void emit(SipEvent event) {
    _events.add(event);
  }

  @override
  Future<void> initialize() async {
    emit(const SipCoreReady());
  }

  @override
  Future<void> shutdown() async {
    await _events.close();
  }

  @override
  Future<void> createAccount(SipAccountConfig config) async {}

  @override
  Future<void> registerAccount(String accountId) async {}

  @override
  Future<void> unregisterAccount(String accountId) async {}

  @override
  Future<String> makeCall({
    required String accountId,
    required String destination,
  }) async {
    return 'outbound-call';
  }

  @override
  Future<void> answerCall(String callId) async {
    answeredCallIds.add(callId);
  }

  @override
  Future<void> rejectCall(String callId) async {
    rejectedCallIds.add(callId);
  }

  @override
  Future<void> hangupCall(String callId) async {
    hungUpCallIds.add(callId);
  }

  @override
  Future<void> holdCall(String callId) async {}

  @override
  Future<void> resumeCall(String callId) async {}

  @override
  Future<void> sendDtmf({
    required String callId,
    required String digits,
  }) async {}

  @override
  Future<void> setMuted({required String callId, required bool muted}) async {}

  @override
  Future<void> setAudioRoute(SipAudioRoute route) async {}
}
