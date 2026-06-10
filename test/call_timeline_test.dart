import 'package:flutter_test/flutter_test.dart';
import 'package:siptalk/sip/call_timeline.dart';
import 'package:siptalk/sip/call_timeline_store.dart';

void main() {
  test('measures duration between call timeline events', () {
    final timeline = CallTimeline(callId: 'call-1');
    final started = DateTime(2026, 6, 10, 9);

    timeline.mark(CallTimelineEvent.pushReceived, at: started);
    timeline.mark(
      CallTimelineEvent.systemUiShown,
      at: started.add(const Duration(milliseconds: 320)),
    );

    expect(
      timeline.durationBetween(
        CallTimelineEvent.pushReceived,
        CallTimelineEvent.systemUiShown,
      ),
      const Duration(milliseconds: 320),
    );
  });

  test('evicts old timelines', () {
    final store = CallTimelineStore(maxTimelines: 2);

    store.mark('call-1', CallTimelineEvent.pushReceived);
    store.mark('call-2', CallTimelineEvent.pushReceived);
    store.mark('call-3', CallTimelineEvent.pushReceived);

    expect(store.all.map((timeline) => timeline.callId), ['call-2', 'call-3']);
  });
}
