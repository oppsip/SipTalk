import 'dart:async';

import 'sip_account.dart';
import 'sip_call.dart';
import 'sip_event.dart';

abstract interface class SipController {
  Stream<SipEvent> get events;

  Future<void> initialize();

  Future<void> shutdown();

  Future<void> createAccount(SipAccountConfig config);

  Future<void> registerAccount(String accountId);

  Future<void> unregisterAccount(String accountId);

  Future<String> makeCall({
    required String accountId,
    required String destination,
  });

  Future<void> answerCall(String callId);

  Future<void> rejectCall(String callId);

  Future<void> hangupCall(String callId);

  Future<void> holdCall(String callId);

  Future<void> resumeCall(String callId);

  Future<void> sendDtmf({required String callId, required String digits});

  Future<void> setMuted({required String callId, required bool muted});

  Future<void> setAudioRoute(SipAudioRoute route);
}

class SipControllerStub implements SipController {
  final _events = StreamController<SipEvent>.broadcast();

  @override
  Stream<SipEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    _events.add(const SipCoreReady());
  }

  @override
  Future<void> shutdown() async {
    await _events.close();
  }

  @override
  Future<void> createAccount(SipAccountConfig config) async {}

  @override
  Future<void> registerAccount(String accountId) async {
    _events.add(
      SipAccountRegistrationChanged(
        accountId: accountId,
        state: SipAccountState.registering,
      ),
    );
  }

  @override
  Future<void> unregisterAccount(String accountId) async {}

  @override
  Future<String> makeCall({
    required String accountId,
    required String destination,
  }) async {
    final callId = DateTime.now().microsecondsSinceEpoch.toString();
    _events.add(
      SipCallStateChanged(
        SipCallInfo(
          id: callId,
          accountId: accountId,
          state: SipCallState.calling,
          remoteUri: destination,
        ),
      ),
    );
    return callId;
  }

  @override
  Future<void> answerCall(String callId) async {}

  @override
  Future<void> rejectCall(String callId) async {}

  @override
  Future<void> hangupCall(String callId) async {}

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
  Future<void> setAudioRoute(SipAudioRoute route) async {
    _events.add(SipAudioRouteChanged(route));
  }
}
