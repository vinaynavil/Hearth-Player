/// Represents a video file in the media library with its metadata and watch status.
class Video {
  final String id;
  final String path;
  final String title;
  final String folderPath;
  final int? durationSeconds;
  final String? thumbnailPath;
  final DateTime dateAdded;
  final int lastWatchedPosition;
  final DateTime? lastWatchedAt;
  final int? fileSizeBytes;

  const Video({
    required this.id,
    required this.path,
    required this.title,
    required this.folderPath,
    this.durationSeconds,
    this.thumbnailPath,
    required this.dateAdded,
    this.lastWatchedPosition = 0,
    this.lastWatchedAt,
    this.fileSizeBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'folderPath': folderPath,
      'durationSeconds': durationSeconds,
      'thumbnailPath': thumbnailPath,
      'dateAdded': dateAdded.toIso8601String(),
      'lastWatchedPosition': lastWatchedPosition,
      'lastWatchedAt': lastWatchedAt?.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
    };
  }

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      id: map['id'] as String,
      path: map['path'] as String,
      title: map['title'] as String,
      folderPath: map['folderPath'] as String,
      durationSeconds: map['durationSeconds'] as int?,
      thumbnailPath: map['thumbnailPath'] as String?,
      dateAdded: DateTime.parse(map['dateAdded'] as String),
      lastWatchedPosition: (map['lastWatchedPosition'] as int?) ?? 0,
      lastWatchedAt: map['lastWatchedAt'] != null
          ? DateTime.parse(map['lastWatchedAt'] as String)
          : null,
      fileSizeBytes: map['fileSizeBytes'] as int?,
    );
  }

  Video copyWith({
    String? id,
    String? path,
    String? title,
    String? folderPath,
    int? durationSeconds,
    String? thumbnailPath,
    DateTime? dateAdded,
    int? lastWatchedPosition,
    DateTime? lastWatchedAt,
    int? fileSizeBytes,
  }) {
    return Video(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      folderPath: folderPath ?? this.folderPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      dateAdded: dateAdded ?? this.dateAdded,
      lastWatchedPosition: lastWatchedPosition ?? this.lastWatchedPosition,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}
