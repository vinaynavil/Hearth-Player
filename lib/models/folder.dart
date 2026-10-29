/// Represents a folder containing videos in the library.
class Folder {
  final String path;
  final String name;
  final int videoCount;
  final bool isQuickAccess;

  const Folder({
    required this.path,
    required this.name,
    this.videoCount = 0,
    this.isQuickAccess = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'videoCount': videoCount,
      'isQuickAccess': isQuickAccess ? 1 : 0,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      path: map['path'] as String,
      name: map['name'] as String,
      videoCount: (map['videoCount'] as int?) ?? 0,
      isQuickAccess: map['isQuickAccess'] == 1 || map['isQuickAccess'] == true,
    );
  }

  Folder copyWith({
    String? path,
    String? name,
    int? videoCount,
    bool? isQuickAccess,
  }) {
    return Folder(
      path: path ?? this.path,
      name: name ?? this.name,
      videoCount: videoCount ?? this.videoCount,
      isQuickAccess: isQuickAccess ?? this.isQuickAccess,
    );
  }
}
