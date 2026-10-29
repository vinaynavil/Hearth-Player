import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'audio_subtitles_panel.dart';
import 'frosted_subtitle_overlay.dart';
import 'speed_panel.dart';
import '../../theme/hearth_theme.dart';

/// Full-window cinema overlay player controls with keyboard shortcuts,
/// auto-hiding top & bottom control bars, hardware video surface,
/// seek scrubber, transport cluster, and track/speed popover panels.
class PlayerControls extends StatefulWidget {
  final Player player;
  final mkv.VideoController videoController;
  final String videoPath;
  final ValueNotifier<Duration> positionNotifier;
  final Duration duration;
  final ValueNotifier<Duration> bufferNotifier;
  final bool isPlaying;
  final double volume;
  final bool isMuted;
  final double playbackSpeed;
  final bool isFullscreen;
  final Tracks tracks;
  final Track activeTrack;
  final int? resumedFromSeconds;
  final Offset subtitleDragOffset;
  final ValueChanged<Offset> onSubtitleDragOffsetChanged;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onScrubberChanged;
  final ValueChanged<double> onScrubberChangeEnd;
  final VoidCallback onStepBackward;
  final VoidCallback onStepForward;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onPlaybackSpeedSelected;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onBackToLibrary;
  final VoidCallback onStartOver;
  final ValueChanged<AudioTrack> onAudioTrackSelected;
  final ValueChanged<SubtitleTrack> onSubtitleTrackSelected;
  final VoidCallback onLoadSubtitleFile;

  static const List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.4),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  const PlayerControls({
    super.key,
    required this.player,
    required this.videoController,
    required this.videoPath,
    required this.positionNotifier,
    required this.duration,
    required this.bufferNotifier,
    required this.isPlaying,
    required this.volume,
    required this.isMuted,
    required this.playbackSpeed,
    required this.isFullscreen,
    required this.tracks,
    required this.activeTrack,
    required this.resumedFromSeconds,
    required this.subtitleDragOffset,
    required this.onSubtitleDragOffsetChanged,
    required this.onPlayPause,
    required this.onScrubberChanged,
    required this.onScrubberChangeEnd,
    required this.onStepBackward,
    required this.onStepForward,
    required this.onToggleMute,
    required this.onPlaybackSpeedSelected,
    required this.onToggleFullscreen,
    required this.onBackToLibrary,
    required this.onStartOver,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
    required this.onLoadSubtitleFile,
  });

  static String formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  Timer? _controlsHideTimer;
  bool _areControlsVisible = true;

  final GlobalKey<mkv.VideoState> _videoStateKey = GlobalKey<mkv.VideoState>();
  final GlobalKey _tracksPanelKey = GlobalKey();
  final GlobalKey _speedPanelKey = GlobalKey();

  bool _isTracksPanelOpen = false;
  bool _isSpeedPanelOpen = false;
  ui.Image? _tracksPanelSnapshotImage;
  ui.Image? _speedPanelSnapshotImage;

  Timer? _tracksPanelOpenTimer;
  Timer? _tracksPanelCloseTimer;
  Timer? _speedPanelOpenTimer;
  Timer? _speedPanelCloseTimer;

  late Widget _videoSurface;

  void _initVideoSurface() {
    _videoSurface = RepaintBoundary(
      key: const ValueKey('video_surface'),
      child: mkv.Video(
        key: _videoStateKey,
        controller: widget.videoController,
        controls: mkv.NoVideoControls,
        subtitleViewConfiguration:
            const mkv.SubtitleViewConfiguration(visible: false),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initVideoSurface();
    _startControlsHideTimer();
  }

  @override
  void didUpdateWidget(covariant PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoController != oldWidget.videoController) {
      _initVideoSurface();
    }
    if (widget.isFullscreen != oldWidget.isFullscreen) {
      _closeTracksPanelImmediately();
      _onPlayerUserInteraction();
    }
    if (widget.videoPath != oldWidget.videoPath) {
      _closeTracksPanelImmediately();
      _onPlayerUserInteraction();
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (!widget.isPlaying) {
        _controlsHideTimer?.cancel();
        if (!_areControlsVisible) {
          setState(() => _areControlsVisible = true);
        }
      } else {
        _onPlayerUserInteraction();
      }
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _tracksPanelOpenTimer?.cancel();
    _tracksPanelCloseTimer?.cancel();
    _speedPanelOpenTimer?.cancel();
    _speedPanelCloseTimer?.cancel();
    _tracksPanelSnapshotImage?.dispose();
    _speedPanelSnapshotImage?.dispose();
    super.dispose();
  }

  void _onPlayerUserInteraction() {
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _startControlsHideTimer();
  }

  void _startControlsHideTimer() {
    _controlsHideTimer?.cancel();
    if (_isTracksPanelOpen || _isSpeedPanelOpen) {
      return;
    }
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          widget.isPlaying &&
          !_isTracksPanelOpen &&
          !_isSpeedPanelOpen) {
        setState(() => _areControlsVisible = false);
      }
    });
  }

  void _closeTracksPanelImmediately() {
    _cancelOpenTracksPanel();
    _cancelCloseTracksPanel();
    _cancelOpenSpeedPanel();
    _cancelCloseSpeedPanel();
    _tracksPanelSnapshotImage?.dispose();
    _tracksPanelSnapshotImage = null;
    _speedPanelSnapshotImage?.dispose();
    _speedPanelSnapshotImage = null;
    if (_isTracksPanelOpen || _isSpeedPanelOpen) {
      setState(() {
        _isTracksPanelOpen = false;
        _isSpeedPanelOpen = false;
      });
    }
  }

  Rect? _getPanelScreenRect(GlobalKey key) {
    final RenderBox? box =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
      final Offset globalOffset = box.localToGlobal(Offset.zero);
      return globalOffset & box.size;
    }
    return null;
  }

  Future<ui.Image?> _cropScreenshotToRect({
    required Uint8List bytes,
    required Rect panelScreenRect,
  }) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image fullImage = frameInfo.image;

      if (!mounted) {
        fullImage.dispose();
        return null;
      }

      final double imgW = fullImage.width.toDouble();
      final double imgH = fullImage.height.toDouble();
      if (imgW <= 0 || imgH <= 0) {
        fullImage.dispose();
        return null;
      }

      final RenderBox? videoBox =
          _videoStateKey.currentContext?.findRenderObject() as RenderBox?;
      final Size videoBoxSize = (videoBox != null && videoBox.hasSize)
          ? videoBox.size
          : MediaQuery.sizeOf(context);
      final Offset videoBoxOffset = (videoBox != null && videoBox.hasSize)
          ? videoBox.localToGlobal(Offset.zero)
          : Offset.zero;

      final double videoAspect = imgW / imgH;
      final double boxAspect = videoBoxSize.width / videoBoxSize.height;

      double renderedW, renderedH, offsetInBoxX, offsetInBoxY;
      if (boxAspect > videoAspect) {
        renderedH = videoBoxSize.height;
        renderedW = videoBoxSize.height * videoAspect;
        offsetInBoxX = (videoBoxSize.width - renderedW) / 2.0;
        offsetInBoxY = 0.0;
      } else {
        renderedW = videoBoxSize.width;
        renderedH = videoBoxSize.width / videoAspect;
        offsetInBoxX = 0.0;
        offsetInBoxY = (videoBoxSize.height - renderedH) / 2.0;
      }

      final double actualVideoLeft = videoBoxOffset.dx + offsetInBoxX;
      final double actualVideoTop = videoBoxOffset.dy + offsetInBoxY;

      final double scaleX = imgW / renderedW;
      final double scaleY = imgH / renderedH;

      final double srcX =
          ((panelScreenRect.left - actualVideoLeft) * scaleX).clamp(0.0, imgW);
      final double srcY =
          ((panelScreenRect.top - actualVideoTop) * scaleY).clamp(0.0, imgH);
      final double srcW =
          (panelScreenRect.width * scaleX).clamp(1.0, math.max(1.0, imgW - srcX));
      final double srcH =
          (panelScreenRect.height * scaleY).clamp(1.0, math.max(1.0, imgH - srcY));

      final int targetW = panelScreenRect.width.round();
      final int targetH = panelScreenRect.height.round();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawImageRect(
        fullImage,
        Rect.fromLTWH(srcX, srcY, srcW, srcH),
        Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image cropped = await picture.toImage(targetW, targetH);

      fullImage.dispose();
      picture.dispose();
      return cropped;
    } catch (_) {
      return null;
    }
  }

  void _scheduleOpenTracksPanel() {
    _tracksPanelCloseTimer?.cancel();
    _tracksPanelCloseTimer = null;
    if (_isTracksPanelOpen) return;
    _tracksPanelOpenTimer?.cancel();
    _tracksPanelOpenTimer = null;

    widget.player.screenshot().then((Uint8List? bytes) async {
      if (bytes == null || !mounted || _isTracksPanelOpen) return;
      final Rect? panelRect = _getPanelScreenRect(_tracksPanelKey);
      if (panelRect == null) return;
      final ui.Image? cropped = await _cropScreenshotToRect(
        bytes: bytes,
        panelScreenRect: panelRect,
      );
      if (mounted && !_isTracksPanelOpen) {
        setState(() {
          _tracksPanelSnapshotImage?.dispose();
          _tracksPanelSnapshotImage = cropped;
        });
      } else {
        cropped?.dispose();
      }
    });

    _tracksPanelOpenTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _areControlsVisible && !_isTracksPanelOpen) {
        setState(() => _isTracksPanelOpen = true);
        _controlsHideTimer?.cancel();
      }
    });
  }

  void _cancelOpenTracksPanel() {
    _tracksPanelOpenTimer?.cancel();
    _tracksPanelOpenTimer = null;
    _tracksPanelSnapshotImage?.dispose();
    _tracksPanelSnapshotImage = null;
  }

  void _scheduleCloseTracksPanel() {
    if (!_isTracksPanelOpen && _tracksPanelOpenTimer == null) return;
    if (_tracksPanelCloseTimer != null) return;

    _tracksPanelOpenTimer?.cancel();
    _tracksPanelOpenTimer = null;

    _tracksPanelCloseTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _isTracksPanelOpen) {
        setState(() {
          _isTracksPanelOpen = false;
          _tracksPanelSnapshotImage?.dispose();
          _tracksPanelSnapshotImage = null;
        });
        _tracksPanelCloseTimer = null;
        _onPlayerUserInteraction();
      }
    });
  }

  void _cancelCloseTracksPanel() {
    _tracksPanelCloseTimer?.cancel();
    _tracksPanelCloseTimer = null;
  }

  void _scheduleOpenSpeedPanel() {
    _speedPanelCloseTimer?.cancel();
    _speedPanelCloseTimer = null;
    if (_isSpeedPanelOpen) return;
    _speedPanelOpenTimer?.cancel();
    _speedPanelOpenTimer = null;

    widget.player.screenshot().then((Uint8List? bytes) async {
      if (bytes == null || !mounted || _isSpeedPanelOpen) return;
      final Rect? panelRect = _getPanelScreenRect(_speedPanelKey);
      if (panelRect == null) return;
      final ui.Image? cropped = await _cropScreenshotToRect(
        bytes: bytes,
        panelScreenRect: panelRect,
      );
      if (mounted && !_isSpeedPanelOpen) {
        setState(() {
          _speedPanelSnapshotImage?.dispose();
          _speedPanelSnapshotImage = cropped;
        });
      } else {
        cropped?.dispose();
      }
    });

    _speedPanelOpenTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _areControlsVisible && !_isSpeedPanelOpen) {
        setState(() {
          _isSpeedPanelOpen = true;
          _isTracksPanelOpen = false;
        });
        _controlsHideTimer?.cancel();
      }
    });
  }

  void _cancelOpenSpeedPanel() {
    _speedPanelOpenTimer?.cancel();
    _speedPanelOpenTimer = null;
    _speedPanelSnapshotImage?.dispose();
    _speedPanelSnapshotImage = null;
  }

  void _scheduleCloseSpeedPanel() {
    if (!_isSpeedPanelOpen && _speedPanelOpenTimer == null) return;
    if (_speedPanelCloseTimer != null) return;

    _speedPanelOpenTimer?.cancel();
    _speedPanelOpenTimer = null;

    _speedPanelCloseTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _isSpeedPanelOpen) {
        setState(() {
          _isSpeedPanelOpen = false;
          _speedPanelSnapshotImage?.dispose();
          _speedPanelSnapshotImage = null;
        });
        _speedPanelCloseTimer = null;
        _onPlayerUserInteraction();
      }
    });
  }

  void _cancelCloseSpeedPanel() {
    _speedPanelCloseTimer?.cancel();
    _speedPanelCloseTimer = null;
  }

  Widget _buildTracksButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _cancelOpenTracksPanel();
        _cancelCloseTracksPanel();
        _onPlayerUserInteraction();
        setState(() {
          _isTracksPanelOpen = !_isTracksPanelOpen;
          if (_isTracksPanelOpen) {
            _isSpeedPanelOpen = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _isTracksPanelOpen
              ? const Color(0x99070708)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isTracksPanelOpen
                ? const Color(0x22FFFFFF)
                : Colors.transparent,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.subtitles_rounded,
              color: Colors.white,
              size: 17,
            ),
            SizedBox(width: 7),
            Text(
              'Audio & Subtitles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton() {
    return SizedBox(
      height: 40,
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            _cancelOpenSpeedPanel();
            _cancelCloseSpeedPanel();
            _onPlayerUserInteraction();
            setState(() {
              _isSpeedPanelOpen = !_isSpeedPanelOpen;
              if (_isSpeedPanelOpen) {
                _isTracksPanelOpen = false;
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            child: Text(
              '${widget.playbackSpeed}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fileName = widget.videoPath
        .split(Platform.pathSeparator)
        .last;
    final int totalMs = widget.duration.inMilliseconds;
    final int durSec = widget.duration.inSeconds;

    void handlePlayPause() {
      widget.onPlayPause();
      if (_areControlsVisible) {
        _onPlayerUserInteraction();
      }
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): handlePlayPause,
        const SingleActivator(LogicalKeyboardKey.keyK): handlePlayPause,
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): handlePlayPause,
        const SingleActivator(LogicalKeyboardKey.mediaPlay): handlePlayPause,
        const SingleActivator(LogicalKeyboardKey.mediaPause): handlePlayPause,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): widget.onStepBackward,
        const SingleActivator(LogicalKeyboardKey.keyJ): widget.onStepBackward,
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): widget.onStepBackward,
        const SingleActivator(LogicalKeyboardKey.arrowRight): widget.onStepForward,
        const SingleActivator(LogicalKeyboardKey.keyL): widget.onStepForward,
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): widget.onStepForward,
        const SingleActivator(LogicalKeyboardKey.keyM): widget.onToggleMute,
        const SingleActivator(LogicalKeyboardKey.keyF): widget.onToggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.f11): widget.onToggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isTracksPanelOpen || _isSpeedPanelOpen) {
            _closeTracksPanelImmediately();
            _onPlayerUserInteraction();
          } else if (widget.isFullscreen) {
            widget.onToggleFullscreen();
          } else {
            widget.onBackToLibrary();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          cursor: _areControlsVisible
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          onHover: (_) => _onPlayerUserInteraction(),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (_) => _onPlayerUserInteraction(),
            onPointerMove: (_) => _onPlayerUserInteraction(),
            onPointerDown: (_) => _onPlayerUserInteraction(),
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Hardware-Accelerated Video Surface (Click to Play/Pause, Double-Click Fullscreen)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: widget.onToggleFullscreen,
                    onTap: () {
                      if (_isTracksPanelOpen || _isSpeedPanelOpen) {
                        _closeTracksPanelImmediately();
                        _onPlayerUserInteraction();
                        return;
                      }
                      if (!_areControlsVisible) {
                        _onPlayerUserInteraction();
                      } else {
                        widget.onPlayPause();
                        _onPlayerUserInteraction();
                      }
                    },
                    child: Center(
                      child: _videoSurface,
                    ),
                  ),

                  // 3. Floating "Resumed from MM:SS • Start Over" Pill
                  if (widget.resumedFromSeconds != null)
                    Positioned(
                      top: 74,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: HearthTheme.pillSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            boxShadow: PlayerControls._cardShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Resumed from ${PlayerControls.formatDuration(widget.resumedFromSeconds!)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: HearthTheme.tabularFigures,
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: widget.onStartOver,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HearthTheme.dangerSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: HearthTheme.dangerBorder,
                                    ),
                                  ),
                                  child: const Text(
                                    'Start Over',
                                    style: TextStyle(
                                      color: HearthTheme.dangerText,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 3. Auto-Hiding Top & Bottom Floating Controls
                  IgnorePointer(
                    ignoring: !_areControlsVisible,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // TOP OVERLAY BAR
                        AnimatedSlide(
                          offset: _areControlsVisible
                              ? Offset.zero
                              : const Offset(0.0, -0.08),
                          duration: HearthTheme.durationOverlay,
                          curve: HearthTheme.easeOut,
                          child: AnimatedOpacity(
                            opacity: _areControlsVisible ? 1.0 : 0.0,
                            duration: HearthTheme.durationOverlay,
                            curve: HearthTheme.easeOut,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.85),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: widget.onBackToLibrary,
                                    tooltip: 'Back to Library',
                                    icon: const Icon(
                                      Symbols.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 620,
                                        ),
                                        child: Tooltip(
                                          message: fileName,
                                          waitDuration: const Duration(milliseconds: 500),
                                          child: Text(
                                            HearthTheme.middleTruncate(fileName, maxLength: 64),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  MediaQuery.sizeOf(context).width < 560
                                      ? const SizedBox.shrink()
                                      : const SizedBox(width: 155, height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // BOTTOM OVERLAY BAR
                        AnimatedSlide(
                          offset: _areControlsVisible
                              ? Offset.zero
                              : const Offset(0.0, 0.08),
                          duration: HearthTheme.durationOverlay,
                          curve: HearthTheme.easeOut,
                          child: AnimatedOpacity(
                            opacity: _areControlsVisible ? 1.0 : 0.0,
                            duration: HearthTheme.durationOverlay,
                            curve: HearthTheme.easeOut,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                18,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.9),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Thin Seek Bar with Buffered Track + Remaining Time
                                  ValueListenableBuilder<Duration>(
                                    valueListenable: widget.positionNotifier,
                                    builder: (context, currentPosition, _) {
                                      final int posSec = currentPosition.inSeconds;
                                      final int remainingSec =
                                          (durSec - posSec).clamp(0, durSec);
                                      final double scrubberValue = totalMs > 0
                                          ? (currentPosition.inMilliseconds / totalMs)
                                              .clamp(0.0, 1.0)
                                          : 0.0;
                                      return Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 20,
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 3.5,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 6,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 12,
                                                  ),
                                              activeTrackColor:
                                                  HearthTheme.accent,
                                              secondaryActiveTrackColor: Colors
                                                  .white
                                                  .withValues(alpha: 0.35),
                                              inactiveTrackColor: Colors.white
                                                  .withValues(alpha: 0.18),
                                              thumbColor: Colors.white,
                                            ),
                                            child: ValueListenableBuilder<Duration>(
                                              valueListenable:
                                                  widget.bufferNotifier,
                                              builder: (context, currentBuffer, _) {
                                                final double bufferFraction =
                                                    totalMs > 0
                                                        ? (currentBuffer.inMilliseconds /
                                                                totalMs)
                                                            .clamp(0.0, 1.0)
                                                        : 0.0;
                                                return Slider(
                                                  value: scrubberValue,
                                                  secondaryTrackValue:
                                                      bufferFraction,
                                                  onChanged: totalMs > 0
                                                      ? (double val) {
                                                          _onPlayerUserInteraction();
                                                          widget.onScrubberChanged(val);
                                                        }
                                                      : null,
                                                  onChangeEnd: totalMs > 0
                                                      ? widget.onScrubberChangeEnd
                                                      : null,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        PlayerControls.formatDuration(remainingSec),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: HearthTheme.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                                  const SizedBox(height: 8),

                                  // Bottom Controls Row: Center Transport + Right Badges
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Center Cluster: « 10, Play/Pause, 10 », Volume
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Replay 10 Button
                                          IconButton(
                                            onPressed: () {
                                              _onPlayerUserInteraction();
                                              widget.onStepBackward();
                                            },
                                            tooltip: 'Replay 10s',
                                            icon: const Icon(
                                              Symbols.replay_10_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 18),

                                          // Play / Pause Button
                                          IconButton(
                                            onPressed: () {
                                              _onPlayerUserInteraction();
                                              widget.onPlayPause();
                                            },
                                            icon: Icon(
                                              widget.isPlaying
                                                  ? Symbols.pause_rounded
                                                  : Symbols.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 18),

                                          // Forward 10 Button
                                          IconButton(
                                            onPressed: () {
                                              _onPlayerUserInteraction();
                                              widget.onStepForward();
                                            },
                                            tooltip: 'Forward 10s',
                                            icon: const Icon(
                                              Symbols.forward_10_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 18),

                                          // Volume Icon + Popup/Inline Control
                                          IconButton(
                                            onPressed: () {
                                              _onPlayerUserInteraction();
                                              widget.onToggleMute();
                                            },
                                            tooltip: widget.isMuted || widget.volume == 0.0
                                                ? 'Unmute'
                                                : 'Mute (${widget.volume.round()}%)',
                                            icon: Icon(
                                              widget.isMuted || widget.volume == 0.0
                                                  ? Symbols.volume_off_rounded
                                                  : (widget.volume < 50.0
                                                        ? Symbols
                                                              .volume_down_rounded
                                                        : Symbols
                                                              .volume_up_rounded),
                                              color: widget.isMuted || widget.volume == 0.0
                                                  ? HearthTheme.dangerText
                                                  : Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Right Cluster: Speed Badge, PiP/Minimize, Fullscreen
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Speed Badge Button
                                            MouseRegion(
                                              onEnter: (_) {
                                                _onPlayerUserInteraction();
                                                _scheduleOpenSpeedPanel();
                                              },
                                              onExit: (_) =>
                                                  _scheduleCloseSpeedPanel(),
                                              child: _buildSpeedButton(),
                                            ),


                                            const SizedBox(width: 8),

                                            // Fullscreen Toggle Button
                                            IconButton(
                                              onPressed: widget.onToggleFullscreen,
                                              tooltip: widget.isFullscreen
                                                  ? 'Exit Fullscreen (F11 / Esc)'
                                                  : 'Toggle Fullscreen (F11)',
                                              constraints: const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                widget.isFullscreen
                                                    ? Symbols
                                                          .fullscreen_exit_rounded
                                                    : Symbols.fullscreen_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Custom Frosted Glass Subtitle Box (above controls so drag is never blocked)
                  FrostedSubtitleOverlay(
                    subtitleStream: widget.player.stream.subtitle,
                    areControlsVisible: _areControlsVisible,
                    dragOffset: widget.subtitleDragOffset,
                    onDragOffsetChanged: widget.onSubtitleDragOffsetChanged,
                    onUserInteraction: _onPlayerUserInteraction,
                  ),

                  // 5. Audio & Subtitles Continuous Hover Overlay
                  Positioned(
                    top: 18,
                    right: 24,
                    child: IgnorePointer(
                      ignoring: !_areControlsVisible,
                      child: AnimatedSlide(
                        offset: _areControlsVisible
                            ? Offset.zero
                            : const Offset(0.0, -0.08),
                        duration: HearthTheme.durationOverlay,
                        curve: HearthTheme.easeOut,
                        child: AnimatedOpacity(
                          opacity: _areControlsVisible ? 1.0 : 0.0,
                          duration: HearthTheme.durationOverlay,
                          curve: HearthTheme.easeOut,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MouseRegion(
                                onEnter: (_) {
                                  _onPlayerUserInteraction();
                                  _scheduleOpenTracksPanel();
                                },
                                onExit: (_) => _scheduleCloseTracksPanel(),
                                child: _buildTracksButton(),
                              ),
                              IgnorePointer(
                                ignoring: !(_isTracksPanelOpen && _areControlsVisible),
                                child: MouseRegion(
                                  hitTestBehavior: HitTestBehavior.opaque,
                                  onEnter: (_) {
                                    _onPlayerUserInteraction();
                                    _cancelCloseTracksPanel();
                                  },
                                  onExit: (_) => _scheduleCloseTracksPanel(),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: AudioSubtitlesPanel(
                                      panelKey: _tracksPanelKey,
                                      isVisible:
                                          _isTracksPanelOpen && _areControlsVisible,
                                      snapshotImage: _tracksPanelSnapshotImage,
                                      tracks: widget.tracks,
                                      activeTrack: widget.activeTrack,
                                      onAudioTrackSelected: (track) {
                                        _onPlayerUserInteraction();
                                        widget.onAudioTrackSelected(track);
                                      },
                                      onSubtitleTrackSelected: (track) {
                                        _onPlayerUserInteraction();
                                        widget.onSubtitleTrackSelected(track);
                                      },
                                      onLoadSubtitleFile: widget.onLoadSubtitleFile,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Playback Speed Continuous Hover Overlay
                  Positioned(
                    bottom: 68,
                    right: 87,
                    child: IgnorePointer(
                      ignoring: !_areControlsVisible,
                      child: AnimatedSlide(
                        offset: _areControlsVisible
                            ? Offset.zero
                            : const Offset(0.0, 0.08),
                        duration: HearthTheme.durationOverlay,
                        curve: HearthTheme.easeOut,
                        child: AnimatedOpacity(
                          opacity: _areControlsVisible ? 1.0 : 0.0,
                          duration: HearthTheme.durationOverlay,
                          curve: HearthTheme.easeOut,
                          child: MouseRegion(
                            onEnter: (_) {
                              _onPlayerUserInteraction();
                              _cancelCloseSpeedPanel();
                            },
                            onExit: (_) => _scheduleCloseSpeedPanel(),
                            child: SpeedPanel(
                              panelKey: _speedPanelKey,
                              isVisible:
                                  _isSpeedPanelOpen && _areControlsVisible,
                              snapshotImage: _speedPanelSnapshotImage,
                              currentSpeed: widget.playbackSpeed,
                              onSpeedSelected: (speed) {
                                _onPlayerUserInteraction();
                                _cancelOpenSpeedPanel();
                                _cancelCloseSpeedPanel();
                                _isSpeedPanelOpen = false;
                                _speedPanelSnapshotImage?.dispose();
                                _speedPanelSnapshotImage = null;
                                widget.onPlaybackSpeedSelected(speed);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
