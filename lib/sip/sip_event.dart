import 'sip_account.dart';
import 'sip_call.dart';

sealed class SipEvent {
  const SipEvent();
}

class SipCoreReady extends SipEvent {
  const SipCoreReady();
}

class SipCoreFailed extends SipEvent {
  const SipCoreFailed(this.message);

  final String message;
}

class SipAccountRegistrationChanged extends SipEvent {
  const SipAccountRegistrationChanged({
    required this.accountId,
    required this.state,
    this.reason,
    this.statusCode,
  });

  final String accountId;
  final SipAccountState state;
  final String? reason;
  final int? statusCode;
}

class SipIncomingCall extends SipEvent {
  const SipIncomingCall(this.call);

  final SipCallInfo call;
}

class SipCallStateChanged extends SipEvent {
  const SipCallStateChanged(this.call);

  final SipCallInfo call;
}

class SipAudioRouteChanged extends SipEvent {
  const SipAudioRouteChanged(this.route);

  final SipAudioRoute route;
}

class SipDiagnosticLog extends SipEvent {
  const SipDiagnosticLog({
    required this.level,
    required this.message,
    this.callId,
    this.accountId,
  });

  final String level;
  final String message;
  final String? callId;
  final String? accountId;
}
