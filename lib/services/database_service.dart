import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/folder.dart';
import '../models/video.dart';
import '../models/watch_history_entry.dart';
import '../utils/app_env.dart';

/// Manages the local SQLite database for Hearth on Windows desktop.
///
/// Uses a singleton pattern so only one database connection is ever opened at a time,
/// and stores the database file dynamically inside the user's application support folder.
class DatabaseService {
  /// Single shared instance of [DatabaseService].
  static final DatabaseService instance = DatabaseService._internal();

  /// Holds the active SQLite database connection once opened.
  static Database? _database;

  /// Tracks whether the Windows FFI database engine has been initialized.
  static bool _ffiInitialized = false;

  /// Private constructor to enforce the singleton pattern.
  DatabaseService._internal();

  /// Returns the active database connection, opening and initializing it on first use.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Finds the dynamic app-support directory, initializes desktop SQLite FFI,
  /// and opens (or creates) `hearth_library.db`.
  Future<Database> _initDatabase() async {
    if (!_ffiInitialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _ffiInitialized = true;
    }

    final Directory appSupportDir = await AppEnv.getSupportDirectory();
    final String dbPath = p.join(appSupportDir.path, 'hearth_library.db');

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Creates the `videos`, `folders`, and `watch_history` tables when the database
  /// file is created for the very first time.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS videos (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        title TEXT NOT NULL,
        folderPath TEXT NOT NULL,
        durationSeconds INTEGER,
        thumbnailPath TEXT,
        dateAdded TEXT NOT NULL,
        lastWatchedPosition INTEGER NOT NULL DEFAULT 0,
        lastWatchedAt TEXT,
        fileSizeBytes INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        path TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        videoCount INTEGER NOT NULL DEFAULT 0,
        isQuickAccess INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoId TEXT NOT NULL,
        watchedAt TEXT NOT NULL,
        positionSeconds INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recent_folders (
        path TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        accessedAt TEXT NOT NULL
      )
    ''');
  }

  /// Adds any columns introduced in later schema versions to an existing
  /// database file, without wiping existing data.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE videos ADD COLUMN fileSizeBytes INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recent_folders (
          path TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          accessedAt TEXT NOT NULL
        )
      ''');
    }
  }

  /// Inserts a new [Video] into the database, or updates the existing row
  /// preserving existing metadata (such as duration, progress, thumbnail, and dateAdded)
  /// if a video with the same `id` already exists.
  Future<void> upsertVideo(Video video) async {
    final Database db = await database;
    final List<Map<String, dynamic>> existingRows = await db.query(
      'videos',
      columns: [
        'durationSeconds',
        'thumbnailPath',
        'dateAdded',
        'lastWatchedPosition',
        'lastWatchedAt',
        'fileSizeBytes',
      ],
      where: 'id = ?',
      whereArgs: [video.id],
      limit: 1,
    );

    if (existingRows.isEmpty) {
      await db.insert('videos', video.toMap());
      return;
    }

    final Map<String, dynamic> existing = existingRows.first;
    final Map<String, dynamic> mergedMap = video.toMap();

    mergedMap['durationSeconds'] =
        video.durationSeconds ?? existing['durationSeconds'] as int?;
    mergedMap['thumbnailPath'] =
        video.thumbnailPath ?? existing['thumbnailPath'] as String?;
    mergedMap['fileSizeBytes'] =
        video.fileSizeBytes ?? existing['fileSizeBytes'] as int?;

    if (existing['dateAdded'] != null) {
      mergedMap['dateAdded'] = existing['dateAdded'] as String;
    }

    if (video.lastWatchedPosition == 0 && video.lastWatchedAt == null) {
      mergedMap['lastWatchedPosition'] =
          (existing['lastWatchedPosition'] as int?) ?? 0;
      mergedMap['lastWatchedAt'] = existing['lastWatchedAt'] as String?;
    }

    await db.update(
      'videos',
      mergedMap,
      where: 'id = ?',
      whereArgs: [video.id],
    );
  }

  /// Inserts a new [Folder] into the database, or updates the existing row
  /// if a folder with the same `path` already exists.
  Future<void> upsertFolder(Folder folder) async {
    final Database db = await database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all saved videos from the database and converts them into [Video] objects.
  Future<List<Video>> getAllVideos() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'videos',
      orderBy: 'title ASC',
    );
    return rows.map((Map<String, dynamic> row) => Video.fromMap(row)).toList();
  }

  /// Retrieves all saved folders from the database and converts them into [Folder] objects.
  Future<List<Folder>> getAllFolders() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'folders',
      orderBy: 'name ASC',
    );
    return rows.map((Map<String, dynamic> row) => Folder.fromMap(row)).toList();
  }

  /// Saves a new [WatchHistoryEntry] bookmark into the `watch_history` table.
  Future<void> addWatchHistoryEntry(WatchHistoryEntry entry) async {
    final Database db = await database;
    await db.insert(
      'watch_history',
      entry.toMap(),
    );
  }

  /// Retrieves the watch history for a specific [videoId], ordered from newest to oldest.
  Future<List<WatchHistoryEntry>> getWatchHistoryForVideo(String videoId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'watch_history',
      where: 'videoId = ?',
      whereArgs: [videoId],
      orderBy: 'watchedAt DESC',
    );
    return rows
        .map((Map<String, dynamic> row) => WatchHistoryEntry.fromMap(row))
        .toList();
  }

  /// Records that [path] (folder or subfolder) was just opened, then prunes
  /// the table down to the 3 most recently accessed entries.
  Future<void> recordFolderAccess(String path, String name) async {
    final Database db = await database;
    await db.insert(
      'recent_folders',
      {
        'path': path,
        'name': name,
        'accessedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final List<Map<String, dynamic>> rows = await db.query(
      'recent_folders',
      orderBy: 'accessedAt DESC',
    );
    if (rows.length > 3) {
      for (final Map<String, dynamic> row in rows.skip(3)) {
        await db.delete(
          'recent_folders',
          where: 'path = ?',
          whereArgs: [row['path'] as String],
        );
      }
    }
  }

  /// Returns the 3 most recently accessed folders/subfolders, newest first.
  Future<List<Map<String, dynamic>>> getRecentFolders() async {
    final Database db = await database;
    return db.query(
      'recent_folders',
      orderBy: 'accessedAt DESC',
      limit: 3,
    );
  }
    /// Deletes all rows from the `videos`, `folders`, and `watch_history` tables
    /// to reset the database to a clean slate.
    Future<void> clearDatabase() async {
        final Database db = await database;
        await db.delete('videos');
        await db.delete('folders');
        await db.delete('watch_history');
    }
  /// Returns the last known file size (in bytes) for the video at [path],
  /// or null if no matching row exists or the size was never recorded.
  Future<int?> getKnownFileSize(String path) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'videos',
      columns: ['fileSizeBytes'],
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['fileSizeBytes'] as int?;
  }

  /// Updates only the durationSeconds column for a video by its [videoId] (file path).
  Future<void> updateVideoDuration(String videoId, int durationSeconds) async {
    final Database db = await database;
    await db.update(
      'videos',
      {'durationSeconds': durationSeconds},
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  /// Returns the last known duration (in seconds) for the video at [videoId],
  /// or null if no matching row exists or the duration was never recorded.
  Future<int?> getKnownDuration(String videoId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'videos',
      columns: ['durationSeconds'],
      where: 'id = ?',
      whereArgs: [videoId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['durationSeconds'] as int?;
  }

  /// Returns the last watched position (in seconds) for [path],
  /// or 0 if not found in the database.
  Future<int> getLastWatchedPosition(String path) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'videos',
      columns: ['lastWatchedPosition'],
      where: 'LOWER(path) = LOWER(?)',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['lastWatchedPosition'] as int?) ?? 0;
  }

  /// Removes the video row at [path] entirely (used when a real delete,
  /// not a rename, is confirmed by the file watcher).
  Future<void> markVideoDeleted(String path) async {
    final Database db = await database;
    await db.delete('videos', where: 'path = ?', whereArgs: [path]);
  }

  /// Repoints a video's path after a confirmed rename, preserving its
  /// watch history, thumbnail, and progress. Since this app uses the file
  /// path as the video's id, the id must be updated too, and any existing
  /// watch_history rows must be repointed to the new id in the same
  /// transaction so nothing gets orphaned.
  Future<void> renameVideoPath(String oldPath, String newPath) async {
    final Database db = await database;
    final String newFolderPath = p.dirname(newPath);
    final String newTitle = p.basenameWithoutExtension(newPath);

    await db.transaction((txn) async {
      await txn.update(
        'watch_history',
        {'videoId': newPath},
        where: 'videoId = ?',
        whereArgs: [oldPath],
      );
      await txn.update(
        'videos',
        {
          'id': newPath,
          'path': newPath,
          'title': newTitle,
          'folderPath': newFolderPath,
        },
        where: 'path = ?',
        whereArgs: [oldPath],
      );
    });
  }

  /// Safely closes the database connection if needed when shutting down.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
