/// Represents an entry in the user's video watch history.
class WatchHistoryEntry {
  final String videoId;
  final DateTime watchedAt;
  final int positionSeconds;

  const WatchHistoryEntry({
    required this.videoId,
    required this.watchedAt,
    required this.positionSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'watchedAt': watchedAt.toIso8601String(),
      'positionSeconds': positionSeconds,
    };
  }

  factory WatchHistoryEntry.fromMap(Map<String, dynamic> map) {
    return WatchHistoryEntry(
      videoId: map['videoId'] as String,
      watchedAt: DateTime.parse(map['watchedAt'] as String),
      positionSeconds: (map['positionSeconds'] as int?) ?? 0,
    );
  }

  WatchHistoryEntry copyWith({
    String? videoId,
    DateTime? watchedAt,
    int? positionSeconds,
  }) {
    return WatchHistoryEntry(
      videoId: videoId ?? this.videoId,
      watchedAt: watchedAt ?? this.watchedAt,
      positionSeconds: positionSeconds ?? this.positionSeconds,
    );
  }
}
