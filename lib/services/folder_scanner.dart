import 'dart:io';
import 'package:win32/win32.dart';

import '../models/folder.dart';
import '../models/video.dart';

/// Holds the videos and subfolders found inside a scanned folder.
class ScanResult {
  final List<Video> videos;
  final List<Folder> subfolders;

  const ScanResult({
    required this.videos,
    required this.subfolders,
  });
}

/// Provides dynamic Windows drive detection and folder scanning (both single-level and recursive).
class FolderScanner {
  /// Maximum folder depth for recursive scans to prevent infinite symlink loops.
  static const int _maxRecursionDepth = 15;

  /// Supported video file extensions (always compared in lowercase).
  static const Set<String> _supportedExtensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
  };

  /// System and hidden folders to skip automatically so the scanner stays fast and safe.
  static const Set<String> _ignoredFolderNames = {
    r'$RECYCLE.BIN',
    'System Volume Information',
    'Recovery',
    'PerfLogs',
  };

  /// Dynamically detects all active drive letters on the current Windows machine
  /// using the Win32 API and returns them as a list of [Folder] objects.
  static List<Folder> getAvailableDrives() {
    final List<Folder> drives = [];

    if (!Platform.isWindows) {
      return drives;
    }

    try {
      // GetLogicalDrives returns a bitmask where bit 0 = A:, bit 1 = B:, bit 2 = C:, etc.
      final int bitmask = GetLogicalDrives().value;
      if (bitmask == 0) {
        return drives;
      }

      for (int i = 0; i < 26; i++) {
        if ((bitmask & (1 << i)) != 0) {
          final String driveLetter = String.fromCharCode(65 + i); // 65 is 'A'
          final String driveName = '$driveLetter:';
          final String driveRootPath = '$driveLetter:\\';

          drives.add(
            Folder(
              path: driveRootPath,
              name: driveName,
              videoCount: 0,
              isQuickAccess: false,
            ),
          );
        }
      }
    } catch (_) {
      // Fail safely and return whatever drives were detected so far.
    }

    return drives;
  }

  /// Scans a single folder path ONE LEVEL DEEP (non-recursive) and returns
  /// the supported video files and immediate subfolders directly inside it.
  ///
  /// Difference from [scanFolderRecursive]:
  /// - [scanFolder] only checks the top-level contents of [folderPath]. Use this
  ///   when the user is browsing drives or folders step-by-step in the UI.
  /// - [scanFolderRecursive] digs through all nested subfolders up to 15 levels deep.
  ///
  /// Unreadable files or permission-locked system folders are quietly skipped.
  static ScanResult scanFolder(String folderPath) {
    final List<Video> videos = [];
    final List<Folder> subfolders = [];

    final Directory dir = Directory(folderPath);

    try {
      if (!dir.existsSync()) {
        return const ScanResult(videos: [], subfolders: []);
      }

      // List items one level deep without following symlinks into loops.
      final List<FileSystemEntity> entities = dir.listSync(
        recursive: false,
        followLinks: false,
      );

      for (final FileSystemEntity entity in entities) {
        try {
          final String fullPath = entity.path;
          final String name = _extractName(fullPath);

          if (name.isEmpty) continue;

          if (entity is File) {
            final String extension = _extractExtension(name);
            if (_supportedExtensions.contains(extension)) {
              final String title = _removeExtension(name);

              videos.add(
                Video(
                  id: fullPath,
                  path: fullPath,
                  title: title,
                  folderPath: folderPath,
                  durationSeconds: null,
                  thumbnailPath: null,
                  dateAdded: DateTime.now(),
                  lastWatchedPosition: 0,
                  lastWatchedAt: null,
                  fileSizeBytes: entity.statSync().size,
                ),
              );
            }
          } else if (entity is Directory) {
            // Skip known protected Windows system folders and dot-hidden folders.
            if (_ignoredFolderNames.contains(name) || name.startsWith('.')) {
              continue;
            }

            subfolders.add(
              Folder(
                path: fullPath,
                name: name,
                videoCount: 0,
                isQuickAccess: false,
              ),
            );
          }
        } catch (_) {
          // If a specific file or subfolder throws a permission error, skip it and keep going.
          continue;
        }
      }
    } catch (_) {
      // If the folder itself cannot be opened (e.g., Access Denied), return empty lists safely.
      return const ScanResult(videos: [], subfolders: []);
    }

    return ScanResult(
      videos: videos,
      subfolders: subfolders,
    );
  }

  /// Scans [folderPath] and ALL nested subfolders (up to 15 levels deep) and returns
  /// every video and subfolder found anywhere inside as flat lists in a [ScanResult].
  ///
  /// Difference from [scanFolder]:
  /// - [scanFolderRecursive] walks the entire folder tree (up to [_maxRecursionDepth])
  ///   and collects all videos and folders into flat lists. Use this when indexing a
  ///   library folder or gathering all videos inside a collection.
  /// - [scanFolder] only checks the immediate folder (1 level deep).
  ///
  /// Unreadable files or permission-locked system folders are quietly skipped.
  static ScanResult scanFolderRecursive(String folderPath) {
    final List<Video> allVideos = [];
    final List<Folder> allSubfolders = [];

    _scanRecursiveHelper(
      currentPath: folderPath,
      currentDepth: 0,
      videosOut: allVideos,
      subfoldersOut: allSubfolders,
    );

    return ScanResult(
      videos: allVideos,
      subfolders: allSubfolders,
    );
  }

  /// Internal helper that walks the directory tree up to [_maxRecursionDepth].
  static void _scanRecursiveHelper({
    required String currentPath,
    required int currentDepth,
    required List<Video> videosOut,
    required List<Folder> subfoldersOut,
  }) {
    if (currentDepth > _maxRecursionDepth) {
      return;
    }

    final Directory dir = Directory(currentPath);

    try {
      if (!dir.existsSync()) {
        return;
      }

      final List<FileSystemEntity> entities = dir.listSync(
        recursive: false,
        followLinks: false,
      );

      for (final FileSystemEntity entity in entities) {
        try {
          final String fullPath = entity.path;
          final String name = _extractName(fullPath);

          if (name.isEmpty) continue;

          if (entity is File) {
            final String extension = _extractExtension(name);
            if (_supportedExtensions.contains(extension)) {
              final String title = _removeExtension(name);

              videosOut.add(
                Video(
                  id: fullPath,
                  path: fullPath,
                  title: title,
                  folderPath: currentPath,
                  durationSeconds: null,
                  thumbnailPath: null,
                  dateAdded: DateTime.now(),
                  lastWatchedPosition: 0,
                  lastWatchedAt: null,
                  fileSizeBytes: entity.statSync().size,
                ),
              );
            }
          } else if (entity is Directory) {
            if (_ignoredFolderNames.contains(name) || name.startsWith('.')) {
              continue;
            }

            subfoldersOut.add(
              Folder(
                path: fullPath,
                name: name,
                videoCount: 0,
                isQuickAccess: false,
              ),
            );

            // Recurse into the subfolder if we haven't hit the depth limit.
            if (currentDepth < _maxRecursionDepth) {
              _scanRecursiveHelper(
                currentPath: fullPath,
                currentDepth: currentDepth + 1,
                videosOut: videosOut,
                subfoldersOut: subfoldersOut,
              );
            }
          }
        } catch (_) {
          // Skip individual unreadable files or folders without aborting the scan.
          continue;
        }
      }
    } catch (_) {
      // Skip locked or inaccessible directories quietly.
      return;
    }
  }

  /// Fast check that returns `true` the moment it finds at least ONE supported video
  /// file anywhere inside [folderPath] or its subfolders (up to 15 levels deep).
  ///
  /// When to use:
  /// - Use [folderHasVideosRecursive] when you only need to know whether a folder is
  ///   worth showing in the UI (e.g., filtering out empty/non-media folders) without
  ///   waiting for a full scan of thousands of files.
  /// - Do NOT use this if you need the actual list of videos or total counts; use
  ///   [scanFolder] or [scanFolderRecursive] for that instead.
  static bool folderHasVideosRecursive(String folderPath) {
    return _hasVideosRecursiveHelper(
      currentPath: folderPath,
      currentDepth: 0,
    );
  }

  /// Internal helper that short-circuits and returns `true` on the very first video found.
  static bool _hasVideosRecursiveHelper({
    required String currentPath,
    required int currentDepth,
  }) {
    if (currentDepth > _maxRecursionDepth) {
      return false;
    }

    final Directory dir = Directory(currentPath);

    try {
      if (!dir.existsSync()) {
        return false;
      }

      final List<FileSystemEntity> entities = dir.listSync(
        recursive: false,
        followLinks: false,
      );

      final List<String> directoriesToSearch = [];

      // Pass 1: Check files in the current folder first for the fastest possible exit.
      for (final FileSystemEntity entity in entities) {
        try {
          final String fullPath = entity.path;
          final String name = _extractName(fullPath);

          if (name.isEmpty) continue;

          if (entity is File) {
            final String extension = _extractExtension(name);
            if (_supportedExtensions.contains(extension)) {
              return true; // Found one! Stop scanning immediately.
            }
          } else if (entity is Directory) {
            if (_ignoredFolderNames.contains(name) || name.startsWith('.')) {
              continue;
            }
            directoriesToSearch.add(fullPath);
          }
        } catch (_) {
          continue;
        }
      }

      // Pass 2: Only if no video was in the current folder, check subfolders one by one.
      if (currentDepth < _maxRecursionDepth) {
        for (final String subDirPath in directoriesToSearch) {
          if (_hasVideosRecursiveHelper(
            currentPath: subDirPath,
            currentDepth: currentDepth + 1,
          )) {
            return true; // Found one inside a subfolder! Stop immediately.
          }
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  /// Extracts the file or folder name from the end of a full path.
  static String _extractName(String fullPath) {
    final String normalized = fullPath.replaceAll('/', r'\');
    final String trimmed = normalized.endsWith(r'\')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final int lastSlash = trimmed.lastIndexOf(r'\');
    if (lastSlash == -1) return trimmed;
    return trimmed.substring(lastSlash + 1);
  }

  /// Extracts the lowercase file extension (including the dot, e.g., '.mkv').
  static String _extractExtension(String fileName) {
    final int lastDot = fileName.lastIndexOf('.');
    if (lastDot <= 0) return '';
    return fileName.substring(lastDot).toLowerCase();
  }

  /// Removes the file extension from a file name to create a clean video title.
  static String _removeExtension(String fileName) {
    final int lastDot = fileName.lastIndexOf('.');
    if (lastDot <= 0) return fileName;
    return fileName.substring(0, lastDot);
  }
}