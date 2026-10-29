import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart' hide WindowCaptionButton;

import '../models/folder.dart';
import '../models/sort_options.dart';
import '../models/video.dart';
import '../services/database_service.dart';
import '../services/file_watcher_service.dart';
import '../services/system_drive_service.dart';
import '../services/thumbnail_service.dart';
import '../services/directory_browser_service.dart';
import '../services/media_sorter.dart';
import '../services/update_service.dart';
import '../widgets/player/hearth_video_viewport.dart';
import '../widgets/player/frosted_subtitle_overlay.dart';
import '../widgets/windows_update_dialog.dart';
import '../theme/hearth_theme.dart';
import '../widgets/home/hearth_sidebar.dart';
import '../widgets/home/hearth_top_bar.dart';
import '../widgets/home/hearth_dashboard_view.dart';
import '../widgets/home/hearth_directory_browser.dart';

// =============================================================================
// MAIN TEST HOME SCREEN
// =============================================================================
class HomeScreen extends StatefulWidget {
  final String? initialVideoPath;
  const HomeScreen({super.key, this.initialVideoPath});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _singleInstanceChannel =
      MethodChannel('hearth/single_instance');

  // UI State
  bool _isGridView = true;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  SortField _sortField = SortField.dateAdded;
  SortDirection _sortDirection = SortDirection.descending;
  bool _isPlaying = false;
  String _selectedSidebarItem = 'Videos';
  double _playbackSpeed = 1.0;

  // Real media_kit Player & Controller State
  Player? _player;
  mkv.VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  String? _currentPlayingPath;
  Duration _currentPosition = Duration.zero;
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _bufferNotifier =
      ValueNotifier<Duration>(Duration.zero);
  Duration _currentDuration = Duration.zero;
  bool _showVideoViewport = false;

  StreamSubscription<void>? _libraryChangedSub;
  StreamSubscription<String>? _videoDeletedSub;
  double _volume = 100.0;
  double _previousVolume = 100.0;
  bool _isMuted = false;
  Timer? _progressSaveTimer;
  Timer? _driveRefreshTimer;
  bool _hasCompletedCurrentVideo = false;

  // Now Playing Overlay & Track State
  bool _isFullscreen = false;
  Tracks _tracks = const Tracks();
  Track _activeTrack = const Track();
  int? _resumedFromSeconds;
  Timer? _resumeBannerTimer;
  DateTime? _lastPlayPauseToggleTime;


  // Custom Subtitle Overlay Runtime Drag Position (resets per video)
  Offset _subtitleDragOffset = Offset.zero;

  // Sidebar Rail Collapse State
  bool _isSidebarCollapsed = true;

  // Dynamic Sidebar Quick Access & Drives (resolved from real OS environment)
  List<Map<String, dynamic>> _quickAccessItems = [];
  List<Map<String, dynamic>> _drives = [];
  List<Map<String, dynamic>> _recentFolders = [];

  // Active File Browser State (null = Dashboard view)
  String? _activeDirectoryPath;
  bool _isDirectoryLoading = false;
  String? _directoryError;
  List<Directory> _dirSubfolders = [];
  Map<String, int> _dirSubfolderVideoCounts = {};
  List<File> _dirVideoFiles = [];


  // --- Real data from database ---
  bool _isLoading = true;
  final bool _isScanning = false;
  Video? _continueWatchingVideo;
  List<Video> _inProgressVideos = [];
  List<Folder> _dbFolders = [];
  List<Video> _allVideos = [];

  @override
  void initState() {
    super.initState();

    final initialPath = widget.initialVideoPath;
    if (initialPath != null && initialPath.isNotEmpty) {
      _currentPlayingPath = initialPath;
      _showVideoViewport = true;
      _playVideoFile(initialPath);

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _initQuickAccessPaths();
        _loadRealDrives();
        if (!_isSidebarCollapsed) {
          _startDriveRefreshTimer();
        }
        _loadRecentFolders();
        _loadDataFromDatabase();
        _startFileWatching();
      });
    } else {
      _initQuickAccessPaths();
      _loadRealDrives();
      if (!_isSidebarCollapsed) {
        _startDriveRefreshTimer();
      }
      _loadRecentFolders();
      _loadDataFromDatabase();
      _startFileWatching();
    }

    _singleInstanceChannel.setMethodCallHandler((call) async {
      if (call.method == 'openFile' && call.arguments is String) {
        final rawPath = (call.arguments as String).trim().replaceAll('"', '');
        if (rawPath.isEmpty) return;
        final dotIdx = rawPath.lastIndexOf('.');
        if (dotIdx == -1 || dotIdx == rawPath.length - 1) return;
        final ext = rawPath.substring(dotIdx + 1).toLowerCase();
        if (!DirectoryBrowserService.videoExtensions.contains(ext)) return;
        final file = File(rawPath);
        if (file.existsSync() && mounted) {
          await _playVideoFile(file.absolute.path);
        }
        return;
      }

      if (call.method == 'mediaCommand' && call.arguments is String) {
        if (!_showVideoViewport || _player == null) return;
        final String action = call.arguments as String;
        switch (action) {
          case 'play_pause':
            _togglePlayPause();
            break;
          case 'play':
            final now = DateTime.now();
            if (_lastPlayPauseToggleTime != null &&
                now.difference(_lastPlayPauseToggleTime!).inMilliseconds < 220) {
              return;
            }
            _lastPlayPauseToggleTime = now;
            _player?.play();
            break;
          case 'pause':
          case 'stop':
            final now = DateTime.now();
            if (_lastPlayPauseToggleTime != null &&
                now.difference(_lastPlayPauseToggleTime!).inMilliseconds < 220) {
              return;
            }
            _lastPlayPauseToggleTime = now;
            _player?.pause();
            break;
          case 'next':
            _stepForward();
            break;
          case 'previous':
            _stepBackward();
            break;
        }
        return;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdateOnStartup();
    });
  }

  Future<void> _checkForAppUpdateOnStartup() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdateOnStartup();
    if (!mounted || updateInfo == null) return;
    await WindowsUpdateDialog.show(context, updateInfo, updateService);
  }

  void _startFileWatching() {
    for (final item in _quickAccessItems) {
      final String path = item['path'] as String;
      FileWatcherService.instance.watchFolder(path);
    }

    _libraryChangedSub =
        FileWatcherService.instance.onLibraryChanged.listen((_) {
      if (mounted) _loadDataFromDatabase();
    });

    _videoDeletedSub =
        FileWatcherService.instance.onVideoDeleted.listen((deletedPath) {
      if (_currentPlayingPath == deletedPath) {
        _stopPlaybackAndExit();
      }
    });
  }

  Future<void> _ensurePlayerInitialized() async {
    if (_player != null && _videoController != null) return;

    const PlayerConfiguration playerConfig = PlayerConfiguration(
      libass: false,
      logLevel: MPVLogLevel.error,
    );
    _player = Player(configuration: playerConfig);

    try {
      final dynamic platform = _player!.platform;
      await Future.wait<void>([
        // 1. VLC-style fast shader profile so iGPUs and CPUs never choke on memory bandwidth
        platform.setProperty('profile', 'fast') as Future<void>,
        platform.setProperty('scale', 'bilinear') as Future<void>,
        platform.setProperty('cscale', 'bilinear') as Future<void>,
        platform.setProperty('dither-depth', 'no') as Future<void>,
        platform.setProperty('correct-downscaling', 'no') as Future<void>,
        platform.setProperty('linear-downscaling', 'no') as Future<void>,
        platform.setProperty('sigmoid-upscaling', 'no') as Future<void>,

        // 2. Safe hardware decoding for 8-bit & 10-bit (P010 / HEVC Main 10) + bounded CPU fallback
        platform.setProperty('hwdec', 'auto-safe') as Future<void>,
        platform.setProperty('vd-lavc-threads', '4') as Future<void>,
        platform.setProperty('opengl-dwmflush', 'no') as Future<void>,

        // 3. Immediate Full RGB color handshake & clean keyframe seeking
        platform.setProperty('video-output-levels', 'full') as Future<void>,
        platform.setProperty('target-prim', 'bt.709') as Future<void>,
        platform.setProperty('target-trc', 'srgb') as Future<void>,
        platform.setProperty('hr-seek', 'no') as Future<void>,
        platform.setProperty('hr-seek-framedrop', 'no') as Future<void>,

        // 4. Demuxer cache
        platform.setProperty('demuxer-max-bytes', '32MiB') as Future<void>,
        platform.setProperty('demuxer-max-back-bytes', '8MiB') as Future<void>,
        platform.setProperty('demuxer-readahead-secs', '3') as Future<void>,
      ]);
    } catch (e) {
      debugPrint('Hearth: Error setting native player properties: $e');
    }

    _videoController = mkv.VideoController(
      _player!,
      configuration: const mkv.VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        hwdec: 'auto-safe',
      ),
    );

    _playerSubscriptions.add(
      _player!.stream.playing.listen((bool playing) {
        if (!mounted) return;
        final bool wasPlaying = _isPlaying;
        setState(() => _isPlaying = playing);
        if (wasPlaying && !playing && !_hasCompletedCurrentVideo) {
          _saveWatchProgress();
        }
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.completed.listen((bool completed) {
        if (!mounted || !completed) return;
        _hasCompletedCurrentVideo = true;
        _progressSaveTimer?.cancel();
        _saveWatchProgress(forceReset: true);
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.position.listen((Duration pos) {
        if (!mounted) return;
        _currentPosition = pos;
        _positionNotifier.value = pos;
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.duration.listen((Duration dur) {
        if (!mounted) return;
        _currentDuration = dur;
        _durationNotifier.value = dur;
        setState(() => _currentDuration = dur);
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.volume.listen((double vol) {
        if (!mounted) return;
        setState(() {
          _volume = vol.clamp(0.0, 100.0);
          _isMuted = _volume == 0.0;
        });
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.buffer.listen((Duration buf) {
        if (!mounted) return;
        _bufferNotifier.value = buf;
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.rate.listen((double rate) {
        if (!mounted) return;
        if (_playbackSpeed != rate) {
          setState(() => _playbackSpeed = rate);
        }
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.tracks.listen((Tracks tracks) {
        if (!mounted) return;
        setState(() => _tracks = tracks);
        _syncActiveAudioTrack(tracks);
        _syncActiveSubtitleTrack(tracks);
      }),
    );

    _playerSubscriptions.add(
      _player!.stream.track.listen((Track track) {
        if (!mounted) return;
        setState(() => _activeTrack = track);
        _updateNativeSubtitleVisibility(track.subtitle);
      }),
    );

    await _player!.setVolume(_volume);
  }

  Future<void> _disposePlayer() async {
    for (final sub in _playerSubscriptions) {
      sub.cancel();
    }
    _playerSubscriptions.clear();
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _libraryChangedSub?.cancel();
    _videoDeletedSub?.cancel();
    FileWatcherService.instance.disposeAll();
    _progressSaveTimer?.cancel();
    _driveRefreshTimer?.cancel();
    _resumeBannerTimer?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _bufferNotifier.dispose();
    if (_isFullscreen) {
      windowManager.setFullScreen(false);
    }
    _saveWatchProgress(refreshUi: false);
    for (final sub in _playerSubscriptions) {
      sub.cancel();
    }
    _playerSubscriptions.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
    ThumbnailService.instance.resumeAfterPlayback();
    super.dispose();
  }

  void _togglePlayPause() {
    final now = DateTime.now();
    if (_lastPlayPauseToggleTime != null &&
        now.difference(_lastPlayPauseToggleTime!).inMilliseconds < 220) {
      return;
    }
    _lastPlayPauseToggleTime = now;
    _player?.playOrPause();
  }

  Future<void> _stepBackward() async {
    final int durSec = _currentDuration.inSeconds;
    final int posSec = _positionNotifier.value.inSeconds;
    final int targetSec = (posSec - 10).clamp(0, durSec);
    _hasCompletedCurrentVideo = false;
    _startProgressTimer();
    await _player?.seek(Duration(seconds: targetSec));
    _saveWatchProgress(positionOverride: targetSec);
  }

  Future<void> _stepForward() async {
    final int durSec = _currentDuration.inSeconds;
    final int posSec = _positionNotifier.value.inSeconds;
    final int targetSec = (posSec + 10).clamp(0, durSec);
    _hasCompletedCurrentVideo = false;
    _startProgressTimer();
    await _player?.seek(Duration(seconds: targetSec));
    _saveWatchProgress(positionOverride: targetSec);
  }

  void _toggleMute() {
    if (_isMuted || _volume == 0.0) {
      final double restoreVol = _previousVolume > 0.0 ? _previousVolume : 100.0;
      setState(() {
        _isMuted = false;
        _volume = restoreVol;
      });
      _player?.setVolume(restoreVol);
    } else {
      setState(() {
        _previousVolume = _volume;
        _isMuted = true;
        _volume = 0.0;
      });
      _player?.setVolume(0.0);
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    final player = _player;
    if (player != null) {
      try {
        final dynamic platform = player.platform;
        await platform.setProperty('framedrop', speed > 1.0 ? 'vo' : 'no');
      } catch (_) {}
      await player.setRate(speed);
    }
  }

  Future<void> _pickAndLoadSubtitleFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
        dialogTitle: 'Select Subtitle File',
      );
      if (result.isNotEmpty && result.single.path != null) {
        final String filePath = result.single.path!;
        final String fileName = p.basenameWithoutExtension(filePath);
        final String uri = Uri.file(filePath).toString();
        final SubtitleTrack customTrack = SubtitleTrack.uri(
          uri,
          title: fileName,
        );
        await _player?.setSubtitleTrack(customTrack);
        await Future.delayed(const Duration(milliseconds: 50));
        await _updateNativeSubtitleVisibility(customTrack);
        if (mounted) {
          setState(() {
            _activeTrack = _activeTrack.copyWith(subtitle: customTrack);
          });
        }
      }
    } catch (e) {
      debugPrint('Hearth: Error loading external subtitle: $e');
    }
  }

  Future<void> _toggleFullscreen() async {
    final bool target = !_isFullscreen;
    await windowManager.setFullScreen(target);
    if (mounted) {
      setState(() => _isFullscreen = target);
    }
  }

  void _startProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isPlaying && !_hasCompletedCurrentVideo) {
        _saveWatchProgress(refreshUi: false);
      }
    });
  }

  Future<void> _saveWatchProgress({
    String? pathOverride,
    int? positionOverride,
    int? durationOverride,
    bool forceReset = false,
    bool refreshUi = true,
    bool allowMinimumOneSecond = false,
  }) async {
    final String? path = pathOverride ?? _currentPlayingPath;
    if (path == null) return;

    final int rawPosSec = positionOverride ??
        (_currentPosition.inSeconds > 0
            ? _currentPosition.inSeconds
            : (_player?.state.position.inSeconds ?? 0));
    final int durSec = durationOverride ??
        (_currentDuration.inSeconds > 0
            ? _currentDuration.inSeconds
            : (_player?.state.duration.inSeconds ?? 0));
    final int posSec =
        (allowMinimumOneSecond && rawPosSec <= 0) ? 1 : rawPosSec;

    final bool isNearEnd = durSec > 5 && (durSec - posSec) <= 5;
    final bool shouldReset =
        forceReset || _hasCompletedCurrentVideo || isNearEnd;

    if (shouldReset) {
      _hasCompletedCurrentVideo = true;
      _progressSaveTimer?.cancel();
    }

    final int savedPosition = shouldReset ? 0 : posSec;
    if (!shouldReset && savedPosition <= 0) return;

    final String lowerPath = path.toLowerCase();
    final int existingIdx = _allVideos.indexWhere(
      (v) => v.path.toLowerCase() == lowerPath,
    );
    final Video updatedVideo;

    if (existingIdx != -1) {
      final Video existing = _allVideos[existingIdx];
      String? thumbPath = existing.thumbnailPath;
      if (thumbPath == null || (!_showVideoViewport && !File(thumbPath).existsSync())) {
        thumbPath = ThumbnailService.instance.peekResolved(path);
      }
      updatedVideo = existing.copyWith(
        durationSeconds: durSec > 0 ? durSec : existing.durationSeconds,
        lastWatchedPosition: savedPosition,
        lastWatchedAt: DateTime.now(),
        thumbnailPath: thumbPath ?? existing.thumbnailPath,
      );
      _allVideos[existingIdx] = updatedVideo;
    } else {
      final String fileName = path.split(Platform.pathSeparator).last;
      final int dot = fileName.lastIndexOf('.');
      final String title = dot != -1 ? fileName.substring(0, dot) : fileName;
      final String? thumbPath = ThumbnailService.instance.peekResolved(path);
      updatedVideo = Video(
        id: path,
        path: path,
        title: title,
        folderPath: File(path).parent.path,
        durationSeconds: durSec > 0 ? durSec : null,
        dateAdded: DateTime.now(),
        lastWatchedPosition: savedPosition,
        lastWatchedAt: DateTime.now(),
        thumbnailPath: thumbPath,
      );
    }

    await DatabaseService.instance.upsertVideo(updatedVideo);

    if (!_showVideoViewport &&
        (updatedVideo.thumbnailPath == null ||
            !File(updatedVideo.thumbnailPath!).existsSync())) {
      unawaited(
        ThumbnailService.instance
            .resolveOrGenerateAndUpdateDb(updatedVideo)
            .then((resolved) {
          if (resolved != null && mounted) {
            _loadDataFromDatabase();
          }
        }),
      );
    }

    if (refreshUi && mounted) {
      if (_showVideoViewport) {
        setState(() {});
      } else {
        await _loadDataFromDatabase();
      }
    }
  }


  Future<void> _stopPlaybackAndExit() async {
    _resumeBannerTimer?.cancel();
    _progressSaveTimer?.cancel();
    if (_isFullscreen) {
      await _toggleFullscreen();
    }
    final String? exitingPath = _currentPlayingPath;
    final int exitingPosSec = _currentPosition.inSeconds > 0
        ? _currentPosition.inSeconds
        : (_player?.state.position.inSeconds ?? 0);
    final int exitingDurSec = _currentDuration.inSeconds > 0
        ? _currentDuration.inSeconds
        : (_player?.state.duration.inSeconds ?? 0);

    await _player?.stop();
    ThumbnailService.instance.resumeAfterPlayback();
    unawaited(
      Window.setEffect(
        effect: WindowEffect.mica,
        dark: true,
      ).catchError((_) {}),
    );
    if (mounted) {
      setState(() {
        _showVideoViewport = false;
        _currentPlayingPath = null;
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _currentDuration = Duration.zero;
      });
    }
    if (exitingPath != null) {
      await _saveWatchProgress(
        pathOverride: exitingPath,
        positionOverride: exitingPosSec,
        durationOverride: exitingDurSec,
        allowMinimumOneSecond: true,
        refreshUi: true,
      );
    } else if (mounted) {
      await _loadDataFromDatabase();
    }
    if (mounted) {
      _startDriveRefreshTimer();
    }
    await _disposePlayer();
  }

  Future<void> _playVideoFile(String filePath, {int? startSeconds}) async {
    if (!File(filePath).existsSync()) return;


    if (_player != null &&
        _currentPlayingPath != null &&
        _currentPlayingPath != filePath) {
      await _saveWatchProgress(
        pathOverride: _currentPlayingPath,
        positionOverride: _currentPosition.inSeconds,
        durationOverride: _currentDuration.inSeconds,
        allowMinimumOneSecond: true,
        refreshUi: false,
      );
    }

    int effectiveStart = startSeconds ?? 0;
    if (startSeconds == null) {
      final String lowerFilePath = filePath.toLowerCase();
      final int idx = _allVideos.indexWhere(
        (v) => v.path.toLowerCase() == lowerFilePath,
      );
      if (idx != -1 && _allVideos[idx].lastWatchedPosition > 0) {
        effectiveStart = _allVideos[idx].lastWatchedPosition;
      } else {
        effectiveStart =
            await DatabaseService.instance.getLastWatchedPosition(filePath);
      }
    }

    _hasCompletedCurrentVideo = false;
    _resumeBannerTimer?.cancel();

    await ThumbnailService.instance.pauseForPlayback();
    await _ensurePlayerInitialized();
    unawaited(
      Window.setEffect(
        effect: WindowEffect.disabled,
        dark: true,
      ).catchError((_) {}),
    );
    setState(() {
      _currentPlayingPath = filePath;
      _showVideoViewport = true;
      _resumedFromSeconds = effectiveStart > 0 ? effectiveStart : null;
      _subtitleDragOffset = Offset.zero;
    });
    _stopDriveRefreshTimer();

    if (effectiveStart > 0) {
      _resumeBannerTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() => _resumedFromSeconds = null);
        }
      });
    }

    await _player?.open(
      Media(
        filePath,
        start: effectiveStart > 0 ? Duration(seconds: effectiveStart) : null,
      ),
    );
    await _player?.setRate(_playbackSpeed);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _syncActiveAudioTrack();
        _syncActiveSubtitleTrack();
      }
    });
    _syncActiveAudioTrack();
    _syncActiveSubtitleTrack();
    _startProgressTimer();
    unawaited(
      _saveWatchProgress(
        pathOverride: filePath,
        positionOverride: effectiveStart > 0 ? effectiveStart : 1,
        allowMinimumOneSecond: true,
        refreshUi: false,
      ),
    );
  }

  void _initQuickAccessPaths() {
    _quickAccessItems = SystemDriveService.getQuickAccessPaths();
  }

  Future<void> _loadRealDrives() async {
    final List<Map<String, dynamic>> loadedDrives =
        await SystemDriveService.loadRealDrives();
    if (!mounted) return;
    if (_drives.length == loadedDrives.length) {
      bool isIdentical = true;
      for (int i = 0; i < loadedDrives.length; i++) {
        final Map<String, dynamic> current = _drives[i];
        final Map<String, dynamic> loaded = loadedDrives[i];
        if (current['name'] != loaded['name'] ||
            current['path'] != loaded['path'] ||
            current['freeSpace'] != loaded['freeSpace']) {
          isIdentical = false;
          break;
        }
      }
      if (isIdentical) return;
    }
    setState(() {
      _drives = loadedDrives;
    });
  }

  Future<void> _loadRecentFolders() async {
    final List<Map<String, dynamic>> rows =
        await DatabaseService.instance.getRecentFolders();
    if (!mounted) return;
    setState(() {
      _recentFolders = rows
          .map((row) => {
                'name': row['name'] as String,
                'path': row['path'] as String,
                'icon': Symbols.folder_rounded,
              })
          .toList();
    });
  }

  void _startDriveRefreshTimer() {
    if (!_isSidebarCollapsed && !_showVideoViewport) {
      _driveRefreshTimer?.cancel();
      _driveRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _loadRealDrives();
      });
    }
  }

  void _stopDriveRefreshTimer() {
    _driveRefreshTimer?.cancel();
    _driveRefreshTimer = null;
  }

  void _setSidebarCollapsed(bool collapsed) {
    if (_isSidebarCollapsed == collapsed) return;
    setState(() {
      _isSidebarCollapsed = collapsed;
      if (_isSidebarCollapsed) {
        _stopDriveRefreshTimer();
      } else {
        _startDriveRefreshTimer();
      }
    });
  }

  Future<void> _openDirectory(String path) async {
    final String trimmedPath = path.endsWith(Platform.pathSeparator)
        ? path.substring(0, path.length - 1)
        : path;
    final bool isDriveRoot = RegExp(r'^[A-Za-z]:$').hasMatch(trimmedPath);
    if (!isDriveRoot) {
      final String folderName = p.basename(trimmedPath);
      DatabaseService.instance.recordFolderAccess(path, folderName).then((_) {
        if (mounted) _loadRecentFolders();
      });
    }
    setState(() {
      _activeDirectoryPath = path;
      _isDirectoryLoading = true;
      _directoryError = null;
      _dirSubfolders = [];
      _dirSubfolderVideoCounts = {};
      _dirVideoFiles = [];
    });

    try {
      final result = await DirectoryBrowserService.scanDirectory(path);
      if (!mounted) return;
      setState(() {
        _dirSubfolders = result.subfolders;
        _dirSubfolderVideoCounts = result.subfolderVideoCounts;
        _dirVideoFiles = result.videoFiles;
        _isDirectoryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _directoryError = e is FileSystemException
            ? e.message
            : 'Unable to access "$path" (permission denied or drive not ready).';
        _isDirectoryLoading = false;
      });
    }
  }

  Future<void> _loadDataFromDatabase() async {
    final db = DatabaseService.instance;
    final rawVideos = await db.getAllVideos();
    final rawFolders = await db.getAllFolders();

    final videos = rawVideos.where((v) => File(v.path).existsSync()).toList();
    final folders = rawFolders.where((f) {
      if (!Directory(f.path).existsSync()) return false;
      final String folderPrefix = f.path.endsWith(Platform.pathSeparator)
          ? f.path
          : '${f.path}${Platform.pathSeparator}';
      return videos.any(
        (v) => v.folderPath == f.path || v.folderPath.startsWith(folderPrefix),
      );
    }).toList();

    Video? continueVideo;
    final watchedVideos = videos
        .where((v) => v.lastWatchedAt != null && v.lastWatchedPosition > 0)
        .toList();
    if (watchedVideos.isNotEmpty) {
      watchedVideos.sort(
        (a, b) => b.lastWatchedAt!.compareTo(a.lastWatchedAt!),
      );
      continueVideo = watchedVideos.first;
    }

    final inProgress = videos.where((v) {
      if (v.lastWatchedPosition <= 0) return false;
      if (v.durationSeconds == null || v.durationSeconds! <= 0) return false;
      if (v.id == continueVideo?.id) return false;
      return v.lastWatchedPosition < v.durationSeconds!;
    }).toList();
    inProgress.sort((a, b) {
      final aTime = a.lastWatchedAt ?? DateTime(2000);
      final bTime = b.lastWatchedAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    if (!mounted) return;
    setState(() {
      _allVideos = videos;
      _continueWatchingVideo = continueVideo;
      _inProgressVideos = inProgress;
      _dbFolders = folders;
      _isLoading = false;
    });
  }


  Future<void> _updateNativeSubtitleVisibility(SubtitleTrack track) async {
    final player = _player;
    if (player == null) return;
    await SubtitleTrackEngine.updateNativeSubtitleVisibility(
      player: player,
      tracks: _tracks,
      track: track,
    );
  }

  Future<void> _syncActiveAudioTrack([Tracks? availableTracks]) async {
    final player = _player;
    if (player == null) return;
    final Tracks currentTracks = availableTracks ?? _tracks;
    final resolved = await SubtitleTrackEngine.syncActiveAudioTrack(
      player: player,
      tracks: currentTracks,
    );
    if (resolved != null && mounted) {
      setState(() {
        _activeTrack = _activeTrack.copyWith(audio: resolved);
      });
    }
  }

  Future<void> _syncActiveSubtitleTrack([Tracks? availableTracks]) async {
    final player = _player;
    if (player == null) return;
    final Tracks currentTracks = availableTracks ?? _tracks;
    final resolved = await SubtitleTrackEngine.syncActiveSubtitleTrack(
      player: player,
      tracks: currentTracks,
    );
    if (mounted) {
      setState(() {
        _activeTrack = _activeTrack.copyWith(subtitle: resolved);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNowPlayingFull = _showVideoViewport &&
        _currentPlayingPath != null &&
        _player != null &&
        _videoController != null;

    if (isNowPlayingFull) {
      return HearthVideoViewport(
        player: _player!,
        videoController: _videoController!,
        videoPath: _currentPlayingPath!,
        positionNotifier: _positionNotifier,
        duration: _currentDuration,
        bufferNotifier: _bufferNotifier,
        isPlaying: _isPlaying,
        volume: _volume,
        isMuted: _isMuted,
        playbackSpeed: _playbackSpeed,
        isFullscreen: _isFullscreen,
        tracks: _tracks,
        activeTrack: _activeTrack,
        resumedFromSeconds: _resumedFromSeconds,
        subtitleDragOffset: _subtitleDragOffset,
        onSubtitleDragOffsetChanged: (newOffset) {
          _subtitleDragOffset = newOffset;
        },
        onPlayPause: _togglePlayPause,
        onScrubberChanged: (double val) {
          final int totalMs = _currentDuration.inMilliseconds;
          final int targetMs = (val * totalMs).round();
          _positionNotifier.value = Duration(milliseconds: targetMs);
          _player?.seek(Duration(milliseconds: targetMs));
        },
        onScrubberChangeEnd: (double val) {
          final int totalMs = _currentDuration.inMilliseconds;
          final int targetMs = (val * totalMs).round();
          final int targetSec = (targetMs / 1000).round();
          _hasCompletedCurrentVideo = false;
          _startProgressTimer();
          _saveWatchProgress(positionOverride: targetSec);
        },
        onStepBackward: _stepBackward,
        onStepForward: _stepForward,
        onToggleMute: _toggleMute,
        onPlaybackSpeedSelected: _setPlaybackSpeed,
        onToggleFullscreen: _toggleFullscreen,
        onBackToLibrary: _stopPlaybackAndExit,
        onStartOver: () async {
          _resumeBannerTimer?.cancel();
          setState(() => _resumedFromSeconds = null);
          _hasCompletedCurrentVideo = false;
          await _player?.seek(Duration.zero);
          _saveWatchProgress(positionOverride: 0);
        },
        onAudioTrackSelected: (track) async {
          await _player?.setAudioTrack(track);
          if (mounted) {
            setState(
              () => _activeTrack = _activeTrack.copyWith(audio: track),
            );
          }
        },
        onSubtitleTrackSelected: (track) async {
          await _player?.setSubtitleTrack(track);
          await _updateNativeSubtitleVisibility(track);
          if (mounted) {
            setState(
              () => _activeTrack = _activeTrack.copyWith(subtitle: track),
            );
          }
        },
        onLoadSubtitleFile: _pickAndLoadSubtitleFile,
      );
    }

    if (_showVideoViewport && _currentPlayingPath != null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchQuery.isNotEmpty) {
            _searchFocusNode.unfocus();
            setState(() => _searchQuery = '');
          } else if (_activeDirectoryPath != null) {
            setState(() {
              _activeDirectoryPath = null;
              _selectedSidebarItem = 'Home';
            });
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ColoredBox(
            color: HearthTheme.windowTintTop,
            child: Column(
              children: [
                // 1. HEARTH FLUENT TITLE BAR
                HearthTopBar(
                  searchFocusNode: _searchFocusNode,
                  searchQuery: _searchQuery,
                  activeDirectoryPath: _activeDirectoryPath,
                  isGridView: _isGridView,
                  isScanning: _isScanning,
                  selectedSortField: _sortField,
                  selectedSortDirection: _sortDirection,
                  onSortFieldChanged: (f) => setState(() => _sortField = f),
                  onSortDirectionChanged: (d) => setState(() => _sortDirection = d),
                  onSearchChanged: (query) {
                    setState(() => _searchQuery = query.trim().toLowerCase());
                  },
                  onResetDirectory: () {
                    setState(() {
                      _activeDirectoryPath = null;
                      _selectedSidebarItem = 'Home';
                    });
                  },
                  onViewModeChanged: (isGrid) =>
                      setState(() => _isGridView = isGrid),
                  onOpenFolder: _pickAndPlayVideoFile,
                ),

                // 2. ZERO-WIDTH AUTO-HIDE SIDEBAR (Smooth Push + Frosted Glass) + MAIN CONTENT AREA
                Expanded(
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Smoothly pushing sidebar container (0px when collapsed, 244px when hovered)
                          MouseRegion(
                            onEnter: (_) => _setSidebarCollapsed(false),
                            onExit: (_) => _setSidebarCollapsed(true),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: _isSidebarCollapsed ? 0.0 : 1.0,
                                end: _isSidebarCollapsed ? 0.0 : 1.0,
                              ),
                              duration: HearthTheme.durationOverlay,
                              curve: HearthTheme.easeOut,
                            builder: (context, factor, child) {
                              return ClipRect(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  widthFactor: factor,
                                  child: Opacity(
                                    opacity: factor.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 244,
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: HearthTheme.contentAreaBorder,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                    child: Container(
                                      color: HearthTheme.windowTintBottom,
                                      child: HearthSidebar(
                                        isCollapsed: false,
                                        selectedItem: _selectedSidebarItem,
                                        activeDirectoryPath: _activeDirectoryPath,
                                        quickAccessItems: _quickAccessItems,
                                        recentFolders: _recentFolders,
                                        drives: _drives,
                                        onHomeTap: () {
                                          setState(() {
                                            _activeDirectoryPath = null;
                                            _selectedSidebarItem = 'Home';
                                          });
                                        },
                                        onDirectorySelected: (path, name) {
                                          setState(() => _selectedSidebarItem = name);
                                          _openDirectory(path);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Main Content Area (moves smoothly to the right as the sidebar expands)
                        Expanded(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: HearthTheme.contentAreaSurface,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(_isSidebarCollapsed ? 0.0 : 10.0),
                              ),
                              border: Border(
                                top: const BorderSide(
                                  color: HearthTheme.contentAreaBorder,
                                  width: 1.0,
                                ),
                                left: _isSidebarCollapsed
                                    ? BorderSide.none
                                    : const BorderSide(
                                        color: HearthTheme.contentAreaBorder,
                                        width: 1.0,
                                      ),
                              ),
                            ),
                            child: _buildMainContent(),
                          ),
                        ),
                      ],
                    ),

                    // Invisible 14px Left-Edge Hover Trigger Zone (only active when sidebar is collapsed)
                    if (_isSidebarCollapsed)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 14,
                        child: MouseRegion(
                          onEnter: (_) => _setSidebarCollapsed(false),
                          hitTestBehavior: HitTestBehavior.translucent,
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _pickAndPlayVideoFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select a video file to play',
      type: FileType.custom,
      allowedExtensions: DirectoryBrowserService.videoExtensions.toList(),
    );
    if (result.isEmpty || result.single.path == null) return;
    await _playVideoFile(result.single.path!);
  }

  Widget _buildMainContent() {
    final Widget content;

    if (_isLoading) {
      content = const Center(
        key: ValueKey('main_loading'),
        child: CircularProgressIndicator(color: HearthTheme.accent),
      );
    } else if (_activeDirectoryPath != null) {
      final List<File> filteredDirVideoFiles = _searchQuery.isEmpty
          ? _dirVideoFiles
          : _dirVideoFiles
              .where((f) => f.path
                  .split(Platform.pathSeparator)
                  .last
                  .toLowerCase()
                  .contains(_searchQuery))
              .toList();

      content = HearthDirectoryBrowser(
        key: ValueKey('browser_$_activeDirectoryPath'),
        activeDirectoryPath: _activeDirectoryPath!,
        isDirectoryLoading: _isDirectoryLoading,
        directoryError: _directoryError,
        dirSubfolders: _dirSubfolders,
        dirSubfolderVideoCounts: _dirSubfolderVideoCounts,
        dirVideoFiles: MediaSorter.sortVideoFiles(
            filteredDirVideoFiles, _sortField, _sortDirection),
        allDbVideos: _allVideos,
        isGridView: _isGridView,
        searchQuery: _searchQuery,
        onClearSearch: () => setState(() => _searchQuery = ''),
        onBackToDashboard: () {
          setState(() {
            _activeDirectoryPath = null;
            _selectedSidebarItem = 'Home';
          });
        },
        onOpenDirectory: _openDirectory,
        onPlayVideo: (path, {startSeconds}) =>
            _playVideoFile(path, startSeconds: startSeconds),
      );
    } else {
      final List<Video> filteredAllVideos = _searchQuery.isEmpty
          ? _allVideos
          : _allVideos
              .where((v) => v.title.toLowerCase().contains(_searchQuery))
              .toList();

      content = HearthDashboardView(
        key: ValueKey('dashboard_${_searchQuery.isNotEmpty}'),
        isScanning: _isScanning,
        isGridView: _isGridView,
        continueWatchingVideo: _continueWatchingVideo,
        inProgressVideos: _inProgressVideos,
        folders: _dbFolders,
        allVideos: MediaSorter.sortVideos(
            filteredAllVideos, _sortField, _sortDirection),
        searchQuery: _searchQuery,
        onClearSearch: () => setState(() => _searchQuery = ''),
        onOpenFile: _pickAndPlayVideoFile,
        onPlayVideo: (filePath, {startSeconds}) =>
            _playVideoFile(filePath, startSeconds: startSeconds),
        onOpenFolder: _openDirectory,
      );
    }

    return AnimatedSwitcher(
      duration: HearthTheme.durationMedium,
      switchInCurve: HearthTheme.easeOut,
      switchOutCurve: HearthTheme.easeOut,
      child: content,
    );
  }
}
