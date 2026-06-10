import 'package:siptalk/sip/incoming_call_push.dart';
import 'package:siptalk/sip/call_timeline.dart';
import 'package:siptalk/sip/sip_account.dart';
import 'package:siptalk/sip/sip_call.dart';
import 'package:siptalk/sip/sip_state_machine.dart';

void main() {
  verifyAccountStateMachine();
  verifyCallStateMachine();
  verifyIncomingCallPush();
  verifyPushDeduplication();
  verifyCallTimeline();
}

void verifyAccountStateMachine() {
  final machine = SipStateMachine();
  final configured = machine.transitionAccount(
    SipAccountState.unconfigured,
    SipAccountState.configured,
  );
  final registering = machine.transitionAccount(
    configured,
    SipAccountState.registering,
  );
  final registered = machine.transitionAccount(
    registering,
    SipAccountState.registered,
  );

  assert(registered == SipAccountState.registered);
}

void verifyCallStateMachine() {
  final machine = SipStateMachine();
  final incomingPush = machine.transitionCall(
    SipCallState.idle,
    SipCallState.incomingPush,
  );
  final ringing = machine.transitionCall(incomingPush, SipCallState.ringing);
  final connecting = machine.transitionCall(ringing, SipCallState.connecting);
  final inCall = machine.transitionCall(connecting, SipCallState.inCall);

  assert(inCall == SipCallState.inCall);
}

void verifyIncomingCallPush() {
  final push = IncomingCallPush.fromJson({
    'callId': 'call-1',
    'sipCallId': 'sip-1',
    'accountId': 'default',
    'caller': '1001',
    'timestampMs': 1780000000000,
    'expiresAtMs': 1780000030000,
  });

  assert(push.callId == 'call-1');
  assert(push.caller == '1001');
}

void verifyPushDeduplication() {
  final deduplicator = IncomingCallPushDeduplicator();

  assert(deduplicator.markIfNew('call-1'));
  assert(!deduplicator.markIfNew('call-1'));
  assert(deduplicator.markIfNew('call-2'));
}

void verifyCallTimeline() {
  final timeline = CallTimeline(callId: 'call-1');
  final start = DateTime(2026, 6, 10, 9);

  timeline.mark(CallTimelineEvent.pushReceived, at: start);
  timeline.mark(
    CallTimelineEvent.mediaConnected,
    at: start.add(const Duration(seconds: 2)),
  );

  assert(
    timeline.durationBetween(
          CallTimelineEvent.pushReceived,
          CallTimelineEvent.mediaConnected,
        ) ==
        const Duration(seconds: 2),
  );
}
