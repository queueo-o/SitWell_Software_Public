enum SessionTrend { improved, declined, stable }

/// A completed posture-monitoring session, surfaced on the History and
/// Insights tabs. Sessions are produced when the user taps END SESSION on
/// the Home screen — provider keeps them in memory (most-recent first).
class SessionRecord {
  final int           id;
  final String        name;           // 'Morning' | 'Afternoon' | 'Evening'
  final DateTime      startedAt;
  final Duration      duration;       // total wall-clock time (paused + active)
  final Duration      pausedDuration; // how long the session was paused
  final int           score;          // 0–100, average posture score
  final int           slouches;
  final SessionTrend  trend;          // vs. the previous session

  const SessionRecord({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.duration,
    this.pausedDuration = Duration.zero,
    required this.score,
    required this.slouches,
    this.trend = SessionTrend.stable,
  });

  /// Compare a new score to the most-recent previous score to derive trend.
  /// Used by [PostureProvider.endSession].
  static SessionTrend trendFromDelta(int newScore, int? previousScore) {
    if (previousScore == null) return SessionTrend.stable;
    final delta = newScore - previousScore;
    if (delta > 5)  return SessionTrend.improved;
    if (delta < -5) return SessionTrend.declined;
    return SessionTrend.stable;
  }

  /// "9:00 AM"
  String get timeLabel {
    final h = startedAt.hour % 12 == 0 ? 12 : startedAt.hour % 12;
    final m = startedAt.minute.toString().padLeft(2, '0');
    final period = startedAt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  /// Total duration: "2h 15m" or "45m"
  String get durationLabel {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Active time = total wall-clock time minus any paused time.
  String get activeLabel {
    final activeDur = duration - pausedDuration;
    final safeMs = activeDur.inMilliseconds.clamp(0, duration.inMilliseconds);
    final h = Duration(milliseconds: safeMs).inHours;
    final m = Duration(milliseconds: safeMs).inMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Bucket name based on local-time hour of the session start.
  static String nameForHour(int hour) {
    if (hour >= 5  && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    return 'Evening';
  }

  /// Seed history shown to a brand-new user so the History/Insights pages
  /// aren't empty. Covers the past 7 days so all chart buckets have data.
  /// Dates are anchored to today so they always look fresh.
  static List<SessionRecord> seed() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Helper: build a session that started [daysAgo] days back at [hour].
    SessionRecord mk({
      required int id,
      required int daysAgo,
      required int hour,
      required int durationH,
      required int durationM,
      required int score,
      required int slouches,
      required SessionTrend trend,
    }) {
      final day = today.subtract(Duration(days: daysAgo));
      return SessionRecord(
        id: id,
        name: nameForHour(hour),
        startedAt: day.add(Duration(hours: hour)),
        duration: Duration(hours: durationH, minutes: durationM),
        // pausedDuration defaults to zero for seed data
        score: score,
        slouches: slouches,
        trend: trend,
      );
    }

    final records = [
      // Today
      mk(id: 1001, daysAgo: 0, hour:  9, durationH: 2, durationM: 15, score: 94, slouches:  4, trend: SessionTrend.improved),
      mk(id: 1002, daysAgo: 0, hour: 13, durationH: 3, durationM: 45, score: 78, slouches: 12, trend: SessionTrend.declined),
      // 1 day ago
      mk(id: 1003, daysAgo: 1, hour: 20, durationH: 1, durationM: 30, score: 88, slouches:  6, trend: SessionTrend.stable),
      mk(id: 1004, daysAgo: 1, hour:  9, durationH: 4, durationM:  0, score: 92, slouches:  8, trend: SessionTrend.improved),
      // 2 days ago
      mk(id: 1005, daysAgo: 2, hour:  8, durationH: 1, durationM: 45, score: 85, slouches:  9, trend: SessionTrend.stable),
      mk(id: 1006, daysAgo: 2, hour: 14, durationH: 2, durationM: 30, score: 71, slouches: 15, trend: SessionTrend.declined),
      // 3 days ago
      mk(id: 1007, daysAgo: 3, hour: 10, durationH: 3, durationM:  0, score: 90, slouches:  5, trend: SessionTrend.improved),
      // 4 days ago
      mk(id: 1008, daysAgo: 4, hour:  9, durationH: 2, durationM:  0, score: 82, slouches: 10, trend: SessionTrend.stable),
      mk(id: 1009, daysAgo: 4, hour: 15, durationH: 1, durationM: 15, score: 76, slouches: 13, trend: SessionTrend.declined),
      // 5 days ago
      mk(id: 1010, daysAgo: 5, hour:  8, durationH: 2, durationM: 45, score: 88, slouches:  7, trend: SessionTrend.improved),
      // 6 days ago
      mk(id: 1011, daysAgo: 6, hour: 13, durationH: 1, durationM: 30, score: 80, slouches: 11, trend: SessionTrend.stable),
      mk(id: 1012, daysAgo: 6, hour:  9, durationH: 3, durationM: 15, score: 87, slouches:  6, trend: SessionTrend.improved),
    ];

    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }
}
