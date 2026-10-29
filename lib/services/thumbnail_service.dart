import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import '../utils/app_env.dart';

import '../models/video.dart';
import 'database_service.dart';

/// Top-level convenience function to generate or retrieve a cached thumbnail
/// for [videoPath], saved under [videoId] in the app's support directory.
Future<String?> generateThumbnail(String videoPath, String videoId) {
  return ThumbnailService.instance.generateThumbnail(videoPath, videoId);
}

/// A standalone, 100% offline service that generates video thumbnails using a
/// single reusable, muted [Player] instance (no external ffmpeg.exe needed).
class ThumbnailService {
  ThumbnailService._();

  /// Singleton instance so the app only ever creates one background Player.
  static final ThumbnailService instance = ThumbnailService._();

  /// Shared headless player used exclusively for background snapshots.
  Player? _sharedPlayer;

  Timer? _idleDisposeTimer;
  static const Duration _idleDisposeDelay = Duration(seconds: 2);

  /// Simple lock queue so multiple calls to [generateThumbnail] share the
  /// single [Player] one at a time without stepping on each other.
  Future<void> _queueLock = Future.value();

  bool _isPausedForPlayback = false;
  Completer<void>? _resumeCompleter;

  Future<void> pauseForPlayback() async {
    _isPausedForPlayback = true;
    _resumeCompleter ??= Completer<void>();
    _idleDisposeTimer?.cancel();
    final player = _sharedPlayer;
    _sharedPlayer = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  void resumeAfterPlayback() {
    _isPausedForPlayback = false;
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    }
    _resumeCompleter = null;
  }

  /// Minimum byte size (2.5 KB) for a JPEG screenshot to be considered a valid,
  /// non-black, non-blank scene.
  static const int _minValidFrameBytes = 2500;

  /// Cover image filenames to look for in the same folder as the video file.
  static const List<String> _sidecarCoverNames = [
    'cover.jpg',
    'cover.png',
    'poster.jpg',
    'poster.png',
  ];

  /// Map of video IDs currently queued or generating.
  /// Prevents duplicate requests for the same video from entering the serial queue.
  final Map<String, Future<String?>> _inFlight = {};

  /// Resolved thumbnail paths kept in memory for this app session, so a
  /// widget recreated after a sliver-type change (e.g. List/Grid toggle)
  /// can show the thumbnail immediately instead of flashing a placeholder
  /// while it re-awaits an already-known result.
  final Map<String, String?> _resolvedCache = {};

  /// In-memory duration cache (in seconds) for videos resolved this session.
  final Map<String, int> _durationCache = {};

  /// Revision counter notifier so UI widgets can listen to duration updates.
  final ValueNotifier<int> durationRevision = ValueNotifier<int>(0);

  /// Deduplicates concurrent duration resolution requests.
  final Map<String, Future<int?>> _inFlightDuration = {};

  /// Synchronous lookup for a duration already resolved this session.
  int? peekDuration(String videoId) => _durationCache[videoId];

  /// Synchronous lookup for a value already resolved this session.
  /// Returns null if not yet resolved (caller should fall back to the
  /// normal async generateThumbnail()).
  String? peekResolved(String videoId) {
    final safeId = videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return _resolvedCache[safeId];
  }

  /// Resolves the thumbnail for [video]. If cached on disk or sidecar found,
  /// returns it immediately and ensures [video.thumbnailPath] is updated in DB.
  /// If not found, queues [generateThumbnail] and updates DB when resolved.
  Future<String?> resolveOrGenerateAndUpdateDb(Video video) async {
    final cached = await _checkCacheOrSidecar(video.path, video.id);
    if (cached != null) {
      final safeId = video.id.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      _resolvedCache[safeId] = cached;
      final int? resolvedDur =
          video.durationSeconds ?? _durationCache[video.id];
      if (video.thumbnailPath != cached) {
        await DatabaseService.instance.upsertVideo(
          video.copyWith(
            thumbnailPath: cached,
            durationSeconds: resolvedDur,
          ),
        );
      }
      return cached;
    }

    final path = await generateThumbnail(video.path, video.id);
    final int? resolvedDur =
        video.durationSeconds ?? _durationCache[video.id];
    if (path != null && path != video.thumbnailPath) {
      await DatabaseService.instance.upsertVideo(
        video.copyWith(
          thumbnailPath: path,
          durationSeconds: resolvedDur,
        ),
      );
    }
    return path;
  }

  /// Ensures the duration for [video] is resolved and stored in the database
  /// and in-memory cache, especially when a thumbnail already exists on disk
  /// but `durationSeconds` is not yet populated.
  Future<int?> ensureDurationResolved(Video video) async {
    if ((video.durationSeconds ?? 0) > 0) {
      _durationCache[video.id] = video.durationSeconds!;
      return video.durationSeconds!;
    }
    if (_durationCache.containsKey(video.id)) {
      return _durationCache[video.id];
    }
    if (_inFlightDuration.containsKey(video.id)) {
      return _inFlightDuration[video.id]!;
    }

    final completer = Completer<int?>();
    _inFlightDuration[video.id] = completer.future;

    _queueLock = _queueLock.then((_) async {
      try {
        if (_durationCache.containsKey(video.id)) {
          completer.complete(_durationCache[video.id]);
          return;
        }

        while (_isPausedForPlayback && _resumeCompleter != null) {
          await _resumeCompleter!.future;
        }

        final int? durSec = await () async {
          final player = await _getOrCreateMutedPlayer();
          await player.setVolume(0.0);
          final duration = await _openAndWaitForReady(player, video.path);
          await _stopPlayerSafely(player);
          _idleDisposeTimer?.cancel();
          _idleDisposeTimer = Timer(_idleDisposeDelay, () async {
            final player = _sharedPlayer;
            _sharedPlayer = null;
            if (player != null) {
              await player.dispose();
            }
          });

          if (duration != null && duration.inSeconds > 0) {
            final int sec = duration.inSeconds;
            _durationCache[video.id] = sec;
            await DatabaseService.instance.updateVideoDuration(video.id, sec);
            durationRevision.value++;
            return sec;
          }
          return null;
        }().timeout(const Duration(seconds: 4));

        completer.complete(durSec);
      } catch (e) {
        debugPrint('Duration resolution failed for ${video.path}: $e');
        _idleDisposeTimer?.cancel();
        final brokenPlayer = _sharedPlayer;
        _sharedPlayer = null;
        if (brokenPlayer != null) {
          try {
            await brokenPlayer.dispose();
          } catch (_) {}
        }
        completer.complete(null);
      } finally {
        _inFlightDuration.remove(video.id);
      }
    });

    return completer.future;
  }

  /// Generates a thumbnail for [videoPath] and saves it as `<videoId>.jpg`
  /// inside the application support thumbnail cache folder.
  ///
  /// 1. Checks if the thumbnail is already cached on disk.
  /// 2. Checks the video's folder for `cover.jpg`, `cover.png`, `poster.jpg`,
  ///    or `poster.png` and copies it directly if found.
  /// 3. Otherwise uses a single shared, muted `media_kit` [Player] to seek to
  ///    12% of the video's duration and capture a JPEG screenshot.
  /// 4. If the screenshot is under 4 KB (likely a black screen), retries at 18%.
  /// 5. Returns the saved thumbnail file path, or `null` if extraction fails.
  Future<String?> generateThumbnail(String videoPath, String videoId) async {
    final safeId = videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    final cached = await _checkCacheOrSidecar(videoPath, videoId);
    if (cached != null) {
      _resolvedCache[safeId] = cached;
      return cached;
    }

    if (_inFlight.containsKey(safeId)) {
      return _inFlight[safeId]!;
    }

    final completer = Completer<String?>();
    _inFlight[safeId] = completer.future;
    _queueLock = _queueLock.then((_) async {
      try {
        while (_isPausedForPlayback && _resumeCompleter != null) {
          await _resumeCompleter!.future;
        }
        final result = await _decodeAndSaveThumbnail(videoPath, videoId);
        if (result != null) {
          _resolvedCache[safeId] = result;
        }
        completer.complete(result);
      } catch (e) {
        debugPrint('Thumbnail generation failed: $e');
        completer.complete(null);
      } finally {
        _inFlight.remove(safeId);
      }
    });
    return completer.future;
  }

  /// Lock-free check: returns an existing cached thumbnail path, or a
  /// freshly-copied sidecar cover (cover.jpg/poster.jpg etc.), or null if
  /// neither exists — meaning generation via the shared player is required.
  Future<String?> _checkCacheOrSidecar(String videoPath, String videoId) async {
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      debugPrint('Thumbnail failed: video file does not exist at path: $videoPath');
      return null;
    }
    final safeId = videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final supportDir = await AppEnv.getSupportDirectory();
    final cacheDir = Directory(p.join(supportDir.path, 'thumbnails'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final targetThumbFile = File(p.join(cacheDir.path, '$safeId.jpg'));

    if (await targetThumbFile.exists() &&
        await targetThumbFile.length() >= _minValidFrameBytes) {
      return targetThumbFile.path;
    }

    final videoFolder = videoFile.parent.path;
    for (final fileName in _sidecarCoverNames) {
      final candidate = File(p.join(videoFolder, fileName));
      if (await candidate.exists() && await candidate.length() > 0) {
        await candidate.copy(targetThumbFile.path);
        return targetThumbFile.path;
      }
    }
    return null;
  }

  /// Decodes a frame via the shared media_kit player and saves it. Only
  /// reached when [_checkCacheOrSidecar] found nothing — always runs inside
  /// the serial queue since it touches the single shared Player.
  Future<String?> _decodeAndSaveThumbnail(String videoPath, String videoId) async {
    try {
      final safeId = videoId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final supportDir = await AppEnv.getSupportDirectory();
      final cacheDir = Directory(p.join(supportDir.path, 'thumbnails'));
      final targetThumbFile = File(p.join(cacheDir.path, '$safeId.jpg'));

      return await () async {
        final player = await _getOrCreateMutedPlayer();
        await player.setVolume(0.0);
        final duration = await _openAndWaitForReady(player, videoPath);
        if (duration == null || duration <= Duration.zero) {
          debugPrint('Thumbnail failed: duration was null or zero ($duration)');
          await _stopPlayerSafely(player);
          _idleDisposeTimer?.cancel();
          _idleDisposeTimer = Timer(_idleDisposeDelay, () async {
            final player = _sharedPlayer;
            _sharedPlayer = null;
            if (player != null) {
              await player.dispose();
            }
          });
          return null;
        }

        final int durSec = duration.inSeconds;
        if (durSec > 0) {
          _durationCache[videoId] = durSec;
          await DatabaseService.instance.updateVideoDuration(videoId, durSec);
          durationRevision.value++;
        }

        final firstSeekTarget = Duration(
          milliseconds: (duration.inMilliseconds * 0.12).round(),
        );
        bool captured = await _seekAndCapture(player, firstSeekTarget, targetThumbFile);

        if (!captured || await targetThumbFile.length() < 12000) {
          final retrySeekTarget = Duration(
            milliseconds: (duration.inMilliseconds * 0.18).round(),
          );
          captured = await _seekAndCapture(player, retrySeekTarget, targetThumbFile);
        }

        await _stopPlayerSafely(player);
        _idleDisposeTimer?.cancel();
        _idleDisposeTimer = Timer(_idleDisposeDelay, () async {
          final player = _sharedPlayer;
          _sharedPlayer = null;
          if (player != null) {
            await player.dispose();
          }
        });

        if (!captured || !await targetThumbFile.exists() || await targetThumbFile.length() < _minValidFrameBytes) {
          debugPrint('Thumbnail failed: screenshot missing or undersized after both seek attempts');
          try {
            if (await targetThumbFile.exists()) await targetThumbFile.delete();
          } catch (_) {}
          return null;
        }

        return targetThumbFile.path;
      }().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      _idleDisposeTimer?.cancel();
      final brokenPlayer = _sharedPlayer;
      _sharedPlayer = null;
      if (brokenPlayer != null) {
        try {
          await brokenPlayer.dispose();
        } catch (_) {}
      }
      return null;
    }
  }

  /// Lazily initializes and returns the single muted background [Player].
  Future<Player> _getOrCreateMutedPlayer() async {
    if (_sharedPlayer == null) {
      _sharedPlayer = Player(
        configuration: const PlayerConfiguration(
          vo: 'null',
          libass: false,
          logLevel: MPVLogLevel.error,
        ),
      );
      if (_sharedPlayer!.platform is NativePlayer) {
        final native = _sharedPlayer!.platform as NativePlayer;
        await native.setProperty('vid', 'auto');
        await native.setProperty('aid', 'no');
        await native.setProperty('sid', 'no');
        await native.setProperty('hwdec', 'no');
        await native.setProperty('vd-lavc-threads', '2');
        await native.setProperty('sws-scaler', 'fast-bilinear');
        await native.setProperty('vf', 'scale=640:-2');
        await native.setProperty('screenshot-format', 'jpg');
        await native.setProperty('screenshot-jpeg-quality', '78');
        await native.setProperty('screenshot-tag-colorspace', 'no');
        await native.setProperty('demuxer-max-bytes', '8MiB');
        await native.setProperty('demuxer-max-back-bytes', '2MiB');
        await native.setProperty('hr-seek', 'no');
      }
      await _sharedPlayer!.setVolume(0.0);
    }
    _idleDisposeTimer?.cancel();
    return _sharedPlayer!;
  }

  /// Opens [videoPath] and waits up to 3 seconds for `libmpv` to emit a fresh
  /// container duration AND initialize video track dimensions (SPS/PPS NAL headers)
  /// so subsequent seeks do not hit an uninitialized stream or stale duration.
  Future<Duration?> _openAndWaitForReady(
    Player player,
    String videoPath,
  ) async {
    final durationCompleter = Completer<Duration>();
    final videoReadyCompleter = Completer<void>();

    // Subscribe BEFORE player.open() so we never read stale state from the
    // previous video and never miss a fast event emitted during open().
    final durationSub = player.stream.duration.listen((d) {
      if (d > Duration.zero && !durationCompleter.isCompleted) {
        durationCompleter.complete(d);
      }
    });

    final widthSub = player.stream.width.listen((w) {
      if (w != null && w > 0 && !videoReadyCompleter.isCompleted) {
        videoReadyCompleter.complete();
      }
    });

    try {
      await player.open(Media(videoPath), play: false);

      final duration = await durationCompleter.future.timeout(
        const Duration(seconds: 3),
      );

      // Ensure the video decoder has parsed the stream headers (width > 0)
      // before firing player.seek(). Give a short grace timeout if width
      // hasn't arrived yet so valid files still proceed.
      if ((player.state.width ?? 0) > 0 && !videoReadyCompleter.isCompleted) {
        videoReadyCompleter.complete();
      }
      await videoReadyCompleter.future.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {},
      );

      return duration;
    } catch (e) {
      debugPrint('Thumbnail generation failed waiting for media readiness: $e');
      return null;
    } finally {
      await durationSub.cancel();
      await widthSub.cancel();
    }
  }

  /// Seeks to [target] and uses mpv's native C++ `screenshot-to-file` command
  /// to write the JPEG frame directly to [targetThumbFile].
  Future<bool> _seekAndCapture(
    Player player,
    Duration target,
    File targetThumbFile,
  ) async {
    try {
      await player.seek(target);
      await Future.delayed(const Duration(milliseconds: 250));
      if (player.platform is NativePlayer) {
        final native = player.platform as NativePlayer;
        await native.command([
          'screenshot-to-file',
          targetThumbFile.path,
          'video',
        ]);

        if (!await targetThumbFile.exists() ||
            await targetThumbFile.length() < _minValidFrameBytes) {
          await Future.delayed(const Duration(milliseconds: 250));
          await native.command([
            'screenshot-to-file',
            targetThumbFile.path,
            'video',
          ]);
        }
      }

      return await targetThumbFile.exists() &&
          await targetThumbFile.length() >= _minValidFrameBytes;
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return false;
    }
  }

  /// Stops the shared player so it doesn't hold a Windows file lock on the video.
  Future<void> _stopPlayerSafely(Player player) async {
    try {
      await player.stop();
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
    }
  }

  /// Optional cleanup method when the app closes.
  Future<void> dispose() async {
    _idleDisposeTimer?.cancel();
    final player = _sharedPlayer;
    _sharedPlayer = null;
    if (player != null) {
      await player.dispose();
    }
  }
}