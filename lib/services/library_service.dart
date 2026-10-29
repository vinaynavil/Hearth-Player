import '../models/folder.dart';
import '../models/video.dart';
import 'database_service.dart';
import 'folder_scanner.dart';
import 'thumbnail_service.dart';

/// Holds the summary count of videos and folders saved to the database after a scan.
class LibrarySaveSummary {
  final int videosSaved;
  final int foldersSaved;

  const LibrarySaveSummary({
    required this.videosSaved,
    required this.foldersSaved,
  });
}

/// Bridges [FolderScanner] and [DatabaseService] so scanned videos and non-empty
/// folders are persisted into the local SQLite database.
class LibraryService {
  /// Recursively scans [folderPath], saves all discovered videos to the database,
  /// and saves the top-level folder and any subfolders only if they contain at least
  /// one video.
  ///
  /// Returns a [LibrarySaveSummary] with the total counts of saved videos and folders.
  static Future<LibrarySaveSummary> scanAndSaveFolder(String folderPath) async {
    final DatabaseService db = DatabaseService.instance;

    // 1. Run a full recursive scan on the given folder path.
    final ScanResult scanResult = FolderScanner.scanFolderRecursive(folderPath);

    int videosSaved = 0;
    int foldersSaved = 0;

    // 2. Save every video found into the database.
    for (final Video video in scanResult.videos) {
      final String? thumbnailPath =
          await generateThumbnail(video.path, video.id);
      final int? resolvedDuration = video.durationSeconds ??
          ThumbnailService.instance.peekDuration(video.id);
      final Video videoToSave = video.copyWith(
        thumbnailPath: thumbnailPath,
        durationSeconds: resolvedDuration,
      );
      await db.upsertVideo(videoToSave);
      videosSaved++;
    }

    // 3. Save the top-level folder itself only if it contains at least one video.
    if (FolderScanner.folderHasVideosRecursive(folderPath)) {
      final Folder topFolder = Folder(
        path: folderPath,
        name: _extractFolderName(folderPath),
        videoCount: 0,
        isQuickAccess: false,
      );
      await db.upsertFolder(topFolder);
      foldersSaved++;
    }

    // 4. For each subfolder found, check if it has videos before saving it.
    for (final Folder subfolder in scanResult.subfolders) {
      if (FolderScanner.folderHasVideosRecursive(subfolder.path)) {
        await db.upsertFolder(subfolder);
        foldersSaved++;
      }
    }

    // 5. Return the final counts of saved items.
    return LibrarySaveSummary(
      videosSaved: videosSaved,
      foldersSaved: foldersSaved,
    );
  }

  /// Extracts a clean display name from a folder or drive path.
  static String _extractFolderName(String fullPath) {
    final String normalized = fullPath.replaceAll('/', r'\');
    final String trimmed = normalized.endsWith(r'\')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final int lastSlash = trimmed.lastIndexOf(r'\');
    if (lastSlash == -1) return trimmed;
    return trimmed.substring(lastSlash + 1);
  }
}