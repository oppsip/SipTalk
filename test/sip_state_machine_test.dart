import 'package:flutter_test/flutter_test.dart';
import 'package:siptalk/sip/sip_account.dart';
import 'package:siptalk/sip/sip_call.dart';
import 'package:siptalk/sip/sip_state_machine.dart';

void main() {
  group('SipStateMachine', () {
    test('allows account registration flow', () {
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

      expect(registered, SipAccountState.registered);
    });

    test('allows background push reachable state', () {
      final machine = SipStateMachine();

      final next = machine.transitionAccount(
        SipAccountState.registered,
        SipAccountState.pushReachable,
      );

      expect(next, SipAccountState.pushReachable);
    });

    test('rejects impossible call transitions', () {
      final machine = SipStateMachine();

      expect(
        () => machine.transitionCall(SipCallState.idle, SipCallState.inCall),
        throwsA(isA<SipStateTransitionError>()),
      );
    });

    test('allows incoming push to connected call flow', () {
      final machine = SipStateMachine();

      final incomingPush = machine.transitionCall(
        SipCallState.idle,
        SipCallState.incomingPush,
      );
      final ringing = machine.transitionCall(
        incomingPush,
        SipCallState.ringing,
      );
      final connecting = machine.transitionCall(
        ringing,
        SipCallState.connecting,
      );
      final inCall = machine.transitionCall(connecting, SipCallState.inCall);

      expect(inCall, SipCallState.inCall);
    });
  });
}
