class IncomingCallPush {
  const IncomingCallPush({
    required this.callId,
    required this.sipCallId,
    required this.accountId,
    required this.caller,
    required this.timestamp,
    required this.expiresAt,
    this.displayName,
  });

  final String callId;
  final String sipCallId;
  final String accountId;
  final String caller;
  final String? displayName;
  final DateTime timestamp;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory IncomingCallPush.fromJson(Map<String, Object?> json) {
    return IncomingCallPush(
      callId: _requiredString(json, 'callId'),
      sipCallId: _requiredString(json, 'sipCallId'),
      accountId: _requiredString(json, 'accountId'),
      caller: _requiredString(json, 'caller'),
      displayName: json['displayName'] as String?,
      timestamp: _dateFromMillis(json, 'timestampMs'),
      expiresAt: _dateFromMillis(json, 'expiresAtMs'),
    );
  }
}

class IncomingCallPushDeduplicator {
  IncomingCallPushDeduplicator({this.maxEntries = 128});

  final int maxEntries;
  final _seenCallIds = <String>[];

  bool markIfNew(String callId) {
    if (_seenCallIds.contains(callId)) {
      return false;
    }

    _seenCallIds.add(callId);
    if (_seenCallIds.length > maxEntries) {
      _seenCallIds.removeAt(0);
    }
    return true;
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing required string field: $key');
}

DateTime _dateFromMillis(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  throw FormatException('Missing required integer timestamp field: $key');
}
