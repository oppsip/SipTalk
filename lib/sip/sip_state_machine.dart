import 'sip_account.dart';
import 'sip_call.dart';

class SipStateTransitionError extends Error {
  SipStateTransitionError(this.message);

  final String message;

  @override
  String toString() => 'SipStateTransitionError: $message';
}

class SipStateMachine {
  SipAccountState transitionAccount(
    SipAccountState current,
    SipAccountState next,
  ) {
    if (!_accountTransitions[current]!.contains(next)) {
      throw SipStateTransitionError(
        'Invalid account transition: ${current.name} -> ${next.name}',
      );
    }
    return next;
  }

  SipCallState transitionCall(SipCallState current, SipCallState next) {
    if (!_callTransitions[current]!.contains(next)) {
      throw SipStateTransitionError(
        'Invalid call transition: ${current.name} -> ${next.name}',
      );
    }
    return next;
  }
}

const _accountTransitions = <SipAccountState, Set<SipAccountState>>{
  SipAccountState.unconfigured: {SipAccountState.configured},
  SipAccountState.configured: {
    SipAccountState.registering,
    SipAccountState.offline,
  },
  SipAccountState.registering: {
    SipAccountState.registered,
    SipAccountState.registrationFailed,
    SipAccountState.offline,
  },
  SipAccountState.registered: {
    SipAccountState.registering,
    SipAccountState.pushReachable,
    SipAccountState.offline,
  },
  SipAccountState.registrationFailed: {
    SipAccountState.registering,
    SipAccountState.pushReachable,
    SipAccountState.offline,
  },
  SipAccountState.pushReachable: {
    SipAccountState.registering,
    SipAccountState.offline,
  },
  SipAccountState.offline: {
    SipAccountState.registering,
    SipAccountState.configured,
  },
};

const _callTransitions = <SipCallState, Set<SipCallState>>{
  SipCallState.idle: {
    SipCallState.incomingPush,
    SipCallState.incomingSip,
    SipCallState.calling,
  },
  SipCallState.incomingPush: {
    SipCallState.incomingSip,
    SipCallState.ringing,
    SipCallState.ended,
    SipCallState.failed,
  },
  SipCallState.incomingSip: {
    SipCallState.ringing,
    SipCallState.connecting,
    SipCallState.ended,
    SipCallState.failed,
  },
  SipCallState.ringing: {
    SipCallState.connecting,
    SipCallState.terminating,
    SipCallState.ended,
  },
  SipCallState.calling: {
    SipCallState.connecting,
    SipCallState.terminating,
    SipCallState.failed,
  },
  SipCallState.connecting: {
    SipCallState.inCall,
    SipCallState.reconnecting,
    SipCallState.terminating,
    SipCallState.failed,
  },
  SipCallState.inCall: {
    SipCallState.held,
    SipCallState.reconnecting,
    SipCallState.terminating,
    SipCallState.ended,
    SipCallState.failed,
  },
  SipCallState.held: {
    SipCallState.inCall,
    SipCallState.terminating,
    SipCallState.ended,
    SipCallState.failed,
  },
  SipCallState.reconnecting: {
    SipCallState.inCall,
    SipCallState.terminating,
    SipCallState.ended,
    SipCallState.failed,
  },
  SipCallState.terminating: {SipCallState.ended, SipCallState.failed},
  SipCallState.ended: {SipCallState.idle},
  SipCallState.failed: {SipCallState.idle},
};
