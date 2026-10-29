import 'dart:io';

/// Result object holding filtered subfolders and video files found in a directory.
class DirectoryScanResult {
  final List<Directory> subfolders;
  final List<File> videoFiles;
  final Map<String, int> subfolderVideoCounts;

  const DirectoryScanResult({
    required this.subfolders,
    required this.videoFiles,
    this.subfolderVideoCounts = const {},
  });

  Map<String, dynamic> toMap() => {
    'subfolders': subfolders,
    'videoFiles': videoFiles,
    'subfolderVideoCounts': subfolderVideoCounts,
  };
}

/// Provides filesystem directory scanning, recursive video detection, and extension filters.
class DirectoryBrowserService {
  static const Set<String> videoExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'wmv',
    'flv',
    'm4v',
    'ts',
    'm2ts',
  };

  /// Recursively checks if a folder contains at least one video file within [maxDepth].
  static Future<bool> folderHasVideoRecursive(
    String path, {
    int maxDepth = 3,
  }) async {
    if (maxDepth < 0) return false;
    try {
      final Directory dir = Directory(path);
      const Set<String> projectMarkers = {
        'package.json',
        'tsconfig.json',
        '.git',
        'pubspec.yaml',
        'cargo.toml',
        'requirements.txt',
      };
      final bool looksLikeProject = projectMarkers.any(
        (marker) =>
            File('$path${Platform.pathSeparator}$marker').existsSync() ||
            Directory('$path${Platform.pathSeparator}$marker').existsSync(),
      );
      if (looksLikeProject) return false;

      await for (final FileSystemEntity entity
          in dir.list(followLinks: false)) {
        final String name = entity.path
            .split(Platform.pathSeparator)
            .where((s) => s.isNotEmpty)
            .last;
        if (name.startsWith('.')) continue;
        if (entity is File) {
          final int dot = name.lastIndexOf('.');
          if (dot != -1) {
            final String ext = name.substring(dot + 1).toLowerCase();
            if (videoExtensions.contains(ext)) return true;
          }
        } else if (entity is Directory) {
          final String upper = name.toUpperCase();
          if (upper == r'$RECYCLE.BIN' ||
              upper == 'SYSTEM VOLUME INFORMATION' ||
              name == '.git' ||
              name == 'node_modules' ||
              name == '.vscode' ||
              name == '.idea' ||
              name == '__pycache__') {
            continue;
          }
          if (await folderHasVideoRecursive(
            entity.path,
            maxDepth: maxDepth - 1,
          )) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Recursively counts all video files inside [path] within [maxDepth].
  static Future<int> countVideosRecursive(
    String path, {
    int maxDepth = 3,
  }) async {
    if (maxDepth < 0) return 0;
    int count = 0;
    try {
      final Directory dir = Directory(path);
      const Set<String> projectMarkers = {
        'package.json',
        'tsconfig.json',
        '.git',
        'pubspec.yaml',
        'cargo.toml',
        'requirements.txt',
      };
      final bool looksLikeProject = projectMarkers.any(
        (marker) =>
            File('$path${Platform.pathSeparator}$marker').existsSync() ||
            Directory('$path${Platform.pathSeparator}$marker').existsSync(),
      );
      if (looksLikeProject) return 0;

      await for (final FileSystemEntity entity
          in dir.list(followLinks: false)) {
        final String name = entity.path
            .split(Platform.pathSeparator)
            .where((s) => s.isNotEmpty)
            .last;
        if (name.startsWith('.')) continue;
        if (entity is File) {
          final int dot = name.lastIndexOf('.');
          if (dot != -1) {
            final String ext = name.substring(dot + 1).toLowerCase();
            if (videoExtensions.contains(ext)) {
              count++;
            }
          }
        } else if (entity is Directory) {
          final String upper = name.toUpperCase();
          if (upper == r'$RECYCLE.BIN' ||
              upper == 'SYSTEM VOLUME INFORMATION' ||
              name == '.git' ||
              name == 'node_modules' ||
              name == '.vscode' ||
              name == '.idea' ||
              name == '__pycache__') {
            continue;
          }
          count += await countVideosRecursive(
            entity.path,
            maxDepth: maxDepth - 1,
          );
        }
      }
    } catch (_) {}
    return count;
  }

  /// Scans a directory on disk, sorts entries, and filters subfolders that contain videos.
  static Future<DirectoryScanResult> scanDirectory(String path) async {
    final Directory dir = Directory(path);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist on disk', path);
    }

    final List<Directory> folders = [];
    final List<File> videos = [];

    await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
      final String name = entity.path
          .split(Platform.pathSeparator)
          .where((s) => s.isNotEmpty)
          .last;
      final String upper = name.toUpperCase();
      if (name.startsWith('.') ||
          upper == r'$RECYCLE.BIN' ||
          upper == 'SYSTEM VOLUME INFORMATION') {
        continue;
      }
      if (entity is Directory) {
        folders.add(entity);
      } else if (entity is File) {
        final int dot = name.lastIndexOf('.');
        if (dot != -1) {
          final String ext = name.substring(dot + 1).toLowerCase();
          if (videoExtensions.contains(ext)) {
            videos.add(entity);
          }
        }
      }
    }

    folders.sort(
      (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
    );
    videos.sort(
      (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
    );

    final List<int> videoCounts = await Future.wait(
      folders.map((f) => countVideosRecursive(f.path)),
    );
    final List<Directory> filteredFolders = [];
    final Map<String, int> subfolderVideoCounts = {};
    for (int i = 0; i < folders.length; i++) {
      if (videoCounts[i] > 0) {
        filteredFolders.add(folders[i]);
        subfolderVideoCounts[folders[i].path] = videoCounts[i];
      }
    }

    return DirectoryScanResult(
      subfolders: filteredFolders,
      videoFiles: videos,
      subfolderVideoCounts: subfolderVideoCounts,
    );
  }
}
