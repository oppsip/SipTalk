class SipCallInfo {
  const SipCallInfo({
    required this.id,
    required this.accountId,
    required this.state,
    this.remoteUri,
    this.displayName,
    this.startedAt,
    this.endedAt,
    this.failureReason,
    this.statusCode,
  });

  final String id;
  final String accountId;
  final SipCallState state;
  final String? remoteUri;
  final String? displayName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? failureReason;
  final int? statusCode;
}

enum SipCallState {
  idle,
  incomingPush,
  incomingSip,
  ringing,
  calling,
  connecting,
  inCall,
  held,
  reconnecting,
  terminating,
  ended,
  failed,
}

enum SipAudioRoute { receiver, speaker, wiredHeadset, bluetooth }
