import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';
import 'database_service.dart';
import 'library_service.dart';

/// Watches scanned folders for file changes and detects
/// deletes vs renames using a short pending-delete buffer.
class FileWatcherService {
  FileWatcherService._internal();
  static final FileWatcherService instance = FileWatcherService._internal();

  final Map<String, DirectoryWatcher> _watchers = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  final StreamController<void> _libraryChangedController =
      StreamController<void>.broadcast();
  final StreamController<String> _videoDeletedController =
      StreamController<String>.broadcast();

  /// Fires whenever a delete, rename, or new file is confirmed and saved —
  /// listeners should reload their video/folder lists from the database.
  Stream<void> get onLibraryChanged => _libraryChangedController.stream;

  /// Fires with the exact path of a video that was just confirmed deleted —
  /// listeners should check if that path is currently playing and stop it.
  Stream<String> get onVideoDeleted => _videoDeletedController.stream;

  // path -> (fileSize, timer) for events waiting to be matched
  final Map<String, _PendingRemoval> _pendingRemovals = {};

  // path -> (fileSize, timer) for ADD events waiting on a possible
  // matching REMOVE, in case the OS fires ADD before REMOVE during a
  // rename (observed to happen in practice, order is not guaranteed).
  final Map<String, _PendingAddition> _pendingAdditions = {};

  static const _matchWindow = Duration(milliseconds: 500);

  /// Call once per top-level folder you want live-watched
  /// (Quick Access dirs + pinned folders).
  void watchFolder(String folderPath) {
    if (_watchers.containsKey(folderPath)) return; // already watching

    final watcher = DirectoryWatcher(folderPath);
    _watchers[folderPath] = watcher;
    _subscriptions[folderPath] = watcher.events.listen(_handleEvent);
  }

  void unwatchFolder(String folderPath) {
    _subscriptions[folderPath]?.cancel();
    _subscriptions.remove(folderPath);
    _watchers.remove(folderPath);
  }

  void disposeAll() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    for (final pending in _pendingRemovals.values) {
      pending.timer.cancel();
    }
    for (final pending in _pendingAdditions.values) {
      pending.timer.cancel();
    }
    _subscriptions.clear();
    _watchers.clear();
    _pendingRemovals.clear();
    _pendingAdditions.clear();
    _libraryChangedController.close();
    _videoDeletedController.close();
  }

  void _handleEvent(WatchEvent event) {
    switch (event.type) {
      case ChangeType.REMOVE:
        unawaited(_handleRemove(event.path));
        break;
      case ChangeType.ADD:
        unawaited(_handleAdd(event.path));
        break;
      case ChangeType.MODIFY:
        // not relevant for delete/rename detection, ignore for now
        break;
    }
  }

  Future<void> _handleRemove(String path) async {
    // We can't stat a file that's already gone, so grab its last
    // known size from the database instead of the filesystem.
    final knownSize = await DatabaseService.instance.getKnownFileSize(path);
    final String dir = File(path).parent.path;

    // Check if a matching ADD already arrived first (order is not
    // guaranteed by the OS during a rename).
    String? matchedNewPath;
    for (final entry in _pendingAdditions.entries) {
      final addedDir = File(entry.key).parent.path;
      if (entry.value.size == knownSize && addedDir == dir) {
        matchedNewPath = entry.key;
        break;
      }
    }

    if (matchedNewPath != null) {
      _pendingAdditions[matchedNewPath]!.timer.cancel();
      _pendingAdditions.remove(matchedNewPath);
      await DatabaseService.instance.renameVideoPath(path, matchedNewPath);
      _libraryChangedController.add(null);
      return;
    }

    final timer = Timer(_matchWindow, () {
      // No matching ADD arrived in time -> treat as a real delete.
      _pendingRemovals.remove(path);
      DatabaseService.instance.markVideoDeleted(path);
      _videoDeletedController.add(path);
      _libraryChangedController.add(null);
    });

    _pendingRemovals[path] = _PendingRemoval(knownSize, timer);
  }

  Future<void> _handleAdd(String newPath) async {
    final file = File(newPath);
    if (!file.existsSync()) return;

    final newSize = file.lengthSync();
    final newDir = File(newPath).parent.path;

    // Look for a pending removal with a matching size in the same folder.
    String? matchedOldPath;
    for (final entry in _pendingRemovals.entries) {
      final oldDir = File(entry.key).parent.path;
      if (entry.value.size == newSize && oldDir == newDir) {
        matchedOldPath = entry.key;
        break;
      }
    }

    if (matchedOldPath != null) {
      // It's a rename: cancel the pending delete, repoint the DB row.
      _pendingRemovals[matchedOldPath]!.timer.cancel();
      _pendingRemovals.remove(matchedOldPath);
      await DatabaseService.instance.renameVideoPath(matchedOldPath, newPath);
      _libraryChangedController.add(null);
      return;
    }

    // No matching REMOVE yet -> the OS may fire REMOVE a moment later
    // for a rename. Hold this ADD briefly before treating it as a
    // genuinely new file.
    final timer = Timer(_matchWindow, () {
      _pendingAdditions.remove(newPath);
      final String parentFolder = File(newPath).parent.path;
      LibraryService.scanAndSaveFolder(parentFolder).then((_) {
        _libraryChangedController.add(null);
      });
    });

    _pendingAdditions[newPath] = _PendingAddition(newSize, timer);
  }
}

class _PendingRemoval {
  final int? size;
  final Timer timer;
  _PendingRemoval(this.size, this.timer);
}

class _PendingAddition {
  final int size;
  final Timer timer;
  _PendingAddition(this.size, this.timer);
}
