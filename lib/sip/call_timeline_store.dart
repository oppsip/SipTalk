import 'call_timeline.dart';

class CallTimelineStore {
  CallTimelineStore({this.maxTimelines = 100});

  final int maxTimelines;
  final _timelines = <String, CallTimeline>{};
  final _order = <String>[];

  CallTimeline timelineFor(String callId) {
    final existing = _timelines[callId];
    if (existing != null) {
      return existing;
    }

    final timeline = CallTimeline(callId: callId);
    _timelines[callId] = timeline;
    _order.add(callId);
    _evictIfNeeded();
    return timeline;
  }

  List<CallTimeline> get all {
    return _order.map((callId) => _timelines[callId]).nonNulls.toList();
  }

  void mark(
    String callId,
    CallTimelineEvent event, {
    DateTime? at,
    String? reason,
    Map<String, Object?> data = const {},
  }) {
    timelineFor(callId).mark(event, at: at, reason: reason, data: data);
  }

  void _evictIfNeeded() {
    while (_order.length > maxTimelines) {
      final removed = _order.removeAt(0);
      _timelines.remove(removed);
    }
  }
}
