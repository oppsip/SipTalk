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

  SipCallInfo copyWith({
    String? id,
    String? accountId,
    SipCallState? state,
    String? remoteUri,
    String? displayName,
    DateTime? startedAt,
    DateTime? endedAt,
    String? failureReason,
    int? statusCode,
  }) {
    return SipCallInfo(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      state: state ?? this.state,
      remoteUri: remoteUri ?? this.remoteUri,
      displayName: displayName ?? this.displayName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      failureReason: failureReason ?? this.failureReason,
      statusCode: statusCode ?? this.statusCode,
    );
  }
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
