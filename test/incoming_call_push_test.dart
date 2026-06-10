import 'package:flutter_test/flutter_test.dart';
import 'package:siptalk/sip/incoming_call_push.dart';

void main() {
  test('parses incoming call push payload', () {
    final push = IncomingCallPush.fromJson({
      'callId': 'call-1',
      'sipCallId': 'sip-1',
      'accountId': 'account-1',
      'caller': '1001',
      'displayName': 'Alice',
      'timestampMs': 1780000000000,
      'expiresAtMs': 1780000030000,
    });

    expect(push.callId, 'call-1');
    expect(push.displayName, 'Alice');
  });

  test('deduplicates repeated call IDs', () {
    final deduplicator = IncomingCallPushDeduplicator();

    expect(deduplicator.markIfNew('call-1'), isTrue);
    expect(deduplicator.markIfNew('call-1'), isFalse);
    expect(deduplicator.markIfNew('call-2'), isTrue);
  });
}
