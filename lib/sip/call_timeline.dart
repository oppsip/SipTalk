class CallTimeline {
  CallTimeline({required this.callId});

  final String callId;
  final List<CallTimelineEntry> _entries = [];

  List<CallTimelineEntry> get entries => List.unmodifiable(_entries);

  void mark(
    CallTimelineEvent event, {
    DateTime? at,
    String? reason,
    Map<String, Object?> data = const {},
  }) {
    _entries.add(
      CallTimelineEntry(
        event: event,
        at: at ?? DateTime.now(),
        reason: reason,
        data: data,
      ),
    );
  }

  Duration? durationBetween(CallTimelineEvent start, CallTimelineEvent end) {
    final startEntry = _first(start);
    final endEntry = _first(end);
    if (startEntry == null || endEntry == null) {
      return null;
    }
    return endEntry.at.difference(startEntry.at);
  }

  CallTimelineEntry? _first(CallTimelineEvent event) {
    for (final entry in _entries) {
      if (entry.event == event) {
        return entry;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return {
      'callId': callId,
      'entries': _entries.map((entry) => entry.toJson()).toList(),
    };
  }
}

class CallTimelineEntry {
  const CallTimelineEntry({
    required this.event,
    required this.at,
    this.reason,
    this.data = const {},
  });

  final CallTimelineEvent event;
  final DateTime at;
  final String? reason;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() {
    return {
      'event': event.name,
      'at': at.toIso8601String(),
      if (reason != null) 'reason': reason,
      if (data.isNotEmpty) 'data': data,
    };
  }
}

enum CallTimelineEvent {
  sipInviteReceived,
  pushSendRequested,
  pushProviderAccepted,
  pushReceived,
  systemUiShown,
  sipCoreRestoring,
  sipRegistered,
  userAnswered,
  sipAnswerSent,
  mediaConnected,
  callEnded,
  callFailed,
}
