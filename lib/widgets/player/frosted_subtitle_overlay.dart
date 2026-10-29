import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../theme/hearth_theme.dart';

/// Player subtitle engine for track synchronization and mpv visibility negotiation.
class SubtitleTrackEngine {
  /// Dynamically toggles native mpv subtitle visibility:
  /// - Text subtitles (SRT, ASS, SSA): set sub-visibility=no so native mpv does not draw underneath Flutter overlay.
  /// - Bitmap subtitles (PGS, VobSub): set sub-visibility=yes so native mpv renders the Blu-ray bitmap overlays.
  /// - Disabled ('no'): set sub-visibility=no.
  static Future<void> updateNativeSubtitleVisibility({
    required Player player,
    required Tracks tracks,
    required SubtitleTrack track,
  }) async {
    try {
      if (track.id == 'no') {
        await (player.platform as dynamic).setProperty('sub-visibility', 'no');
        return;
      }

      // Resolve full track metadata from tracks.subtitle if available
      final SubtitleTrack fullTrack = tracks.subtitle.firstWhere(
        (t) => t.id == track.id,
        orElse: () => track,
      );

      // Default strictly to false (text subtitle) unless confirmed otherwise
      bool isBitmap = false;

      // 1. Direct image flag from media_kit (parsed from mpv track-list image property)
      if (fullTrack.image == true) {
        isBitmap = true;
      }

      // 2. Direct codec string check (e.g. hdmv_pgs_subtitle, pgssub, dvd_subtitle)
      final String codec = (fullTrack.codec ?? '').toLowerCase().trim();
      if (codec.isNotEmpty) {
        if (codec == 'hdmv_pgs_subtitle' ||
            codec == 'pgssub' ||
            codec == 'dvd_subtitle' ||
            codec == 'dvb_subtitle' ||
            codec.contains('pgs') ||
            codec.contains('vobsub')) {
          isBitmap = true;
        }
      }

      // 3. Explicit title indicator match (e.g. English BD-PGS)
      final String title = (fullTrack.title ?? '').toLowerCase().trim();
      if (title.isNotEmpty) {
        if (title.contains('bd-pgs') ||
            title.contains('pgs') ||
            title.contains('vobsub') ||
            title.contains('dvd_sub') ||
            title.contains('.sup')) {
          isBitmap = true;
        }
      }

      final String visibility = isBitmap ? 'yes' : 'no';
      debugPrint(
        'Hearth: _updateNativeSubtitleVisibility track id=${fullTrack.id}, title=${fullTrack.title}, lang=${fullTrack.language}, codec=${fullTrack.codec}, image=${fullTrack.image}, isBitmap=$isBitmap -> sub-visibility=$visibility',
      );
      await (player.platform as dynamic).setProperty(
        'sub-visibility',
        visibility,
      );
    } catch (e) {
      debugPrint('Hearth: Error updating sub-visibility: $e');
    }
  }

  /// Queries active audio track ('aid') from mpv and returns the resolved AudioTrack.
  static Future<AudioTrack?> syncActiveAudioTrack({
    required Player player,
    required Tracks tracks,
  }) async {
    try {
      final realAudio = tracks.audio
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      if (realAudio.isEmpty) return null;

      String? activeAid;
      try {
        final dynamic aidProp = await (player.platform as dynamic).getProperty(
          'aid',
        );
        if (aidProp != null) {
          final String s = aidProp.toString().trim();
          if (s.isNotEmpty && s != 'auto' && s != 'no') {
            activeAid = s;
          }
        }
      } catch (_) {}

      final AudioTrack resolved = activeAid != null
          ? realAudio.firstWhere(
              (t) => t.id == activeAid,
              orElse: () => realAudio.first,
            )
          : realAudio.first;

      return resolved;
    } catch (e) {
      debugPrint('Hearth: Error syncing active audio track: $e');
      return null;
    }
  }

  /// Queries active subtitle track ('sid') from mpv, updates native sub-visibility,
  /// and returns the resolved SubtitleTrack.
  static Future<SubtitleTrack> syncActiveSubtitleTrack({
    required Player player,
    required Tracks tracks,
  }) async {
    try {
      final realSubs = tracks.subtitle
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();

      String? activeSid;
      try {
        final dynamic sidProp = await (player.platform as dynamic).getProperty(
          'sid',
        );
        if (sidProp != null) {
          final String s = sidProp.toString().trim();
          if (s.isNotEmpty && s != 'auto') {
            activeSid = s;
          }
        }
      } catch (_) {}

      final SubtitleTrack resolved;
      if (activeSid == null || activeSid == 'no' || activeSid == 'false') {
        resolved = SubtitleTrack.no();
      } else {
        resolved = realSubs.firstWhere(
          (t) => t.id == activeSid,
          orElse: () => SubtitleTrack.no(),
        );
      }

      await updateNativeSubtitleVisibility(
        player: player,
        tracks: tracks,
        track: resolved,
      );

      return resolved;
    } catch (e) {
      debugPrint('Hearth: Error syncing active subtitle track: $e');
      return SubtitleTrack.no();
    }
  }
}

/// Custom frosted glass subtitle box matching Hearth styling with blur and drag support.
class FrostedSubtitleOverlay extends StatefulWidget {
  final Stream<List<String>> subtitleStream;
  final bool areControlsVisible;
  final Offset dragOffset;
  final ValueChanged<Offset>? onDragOffsetChanged;
  final VoidCallback? onUserInteraction;
  final double fontSize;

  const FrostedSubtitleOverlay({
    super.key,
    required this.subtitleStream,
    required this.areControlsVisible,
    this.dragOffset = Offset.zero,
    this.onDragOffsetChanged,
    this.onUserInteraction,
    this.fontSize = 28.0,
  });

  @override
  State<FrostedSubtitleOverlay> createState() => _FrostedSubtitleOverlayState();
}

class _FrostedSubtitleOverlayState extends State<FrostedSubtitleOverlay> {
  final GlobalKey _subtitleBoxKey = GlobalKey();
  Size _subtitleBoxSize = Size.zero;
  String _lastSubtitleText = '';
  late Offset _dragOffset;

  @override
  void initState() {
    super.initState();
    _dragOffset = widget.dragOffset;
  }

  @override
  void didUpdateWidget(covariant FrostedSubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dragOffset != oldWidget.dragOffset) {
      _dragOffset = widget.dragOffset;
    }
  }

  void _measureSubtitleBox() {
    final RenderBox? renderBox =
        _subtitleBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null &&
        renderBox.hasSize &&
        renderBox.size != _subtitleBoxSize) {
      if (mounted) {
        setState(() {
          _subtitleBoxSize = renderBox.size;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double defaultBottom = widget.areControlsVisible ? 104.0 : 40.0;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return StreamBuilder<List<String>>(
            stream: widget.subtitleStream,
            initialData: const <String>[],
            builder: (context, snapshot) {
              final List<String> lines = snapshot.data ?? const <String>[];
              final String rawText = lines.join('\n').trim();
              final bool hasText = rawText.isNotEmpty;
              if (!hasText) {
                return const SizedBox.shrink();
              }
              _lastSubtitleText = rawText;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _measureSubtitleBox();
              });

              final double boxWidth = _subtitleBoxSize.width > 0
                  ? _subtitleBoxSize.width
                  : 220.0;
              final double boxHeight = _subtitleBoxSize.height > 0
                  ? _subtitleBoxSize.height
                  : 48.0;

              // Clamping limits based on dynamic screen constraints and real rendered box size:
              final double horizontalLimit = math.max(
                0.0,
                (constraints.maxWidth - boxWidth) / 2 - 16.0,
              );
              final double upwardLimit = math.max(
                0.0,
                constraints.maxHeight - defaultBottom - boxHeight - 16.0,
              );
              final double downwardLimit = math.max(0.0, defaultBottom - 16.0);

              final double clampedX = _dragOffset.dx.clamp(
                -horizontalLimit,
                horizontalLimit,
              );
              final double clampedY = _dragOffset.dy.clamp(
                -upwardLimit,
                downwardLimit,
              );

              final double posX =
                  (constraints.maxWidth - boxWidth) / 2 + clampedX;
              final double posY = defaultBottom - clampedY;

              return Stack(
                children: [
                  Positioned(
                    left: posX,
                    bottom: posY,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => widget.onUserInteraction?.call(),
                      onPanUpdate: (DragUpdateDetails details) {
                        final RenderBox? renderBox =
                            _subtitleBoxKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        final double currentW =
                            (renderBox != null &&
                                renderBox.hasSize &&
                                renderBox.size.width > 0)
                            ? renderBox.size.width
                            : boxWidth;
                        final double currentH =
                            (renderBox != null &&
                                renderBox.hasSize &&
                                renderBox.size.height > 0)
                            ? renderBox.size.height
                            : boxHeight;

                        final double hLimit = math.max(
                          0.0,
                          (constraints.maxWidth - currentW) / 2 - 16.0,
                        );
                        final double uLimit = math.max(
                          0.0,
                          constraints.maxHeight -
                              defaultBottom -
                              currentH -
                              16.0,
                        );
                        final double dLimit = math.max(
                          0.0,
                          defaultBottom - 16.0,
                        );

                        final double newX =
                            (_dragOffset.dx + details.delta.dx).clamp(
                              -hLimit,
                              hLimit,
                            );
                        final double newY =
                            (_dragOffset.dy + details.delta.dy).clamp(
                              -uLimit,
                              dLimit,
                            );

                        setState(() {
                          _dragOffset = Offset(newX, newY);
                          if (renderBox != null && renderBox.hasSize) {
                            _subtitleBoxSize = renderBox.size;
                          }
                        });

                        widget.onDragOffsetChanged?.call(_dragOffset);
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: Container(
                          key: _subtitleBoxKey,
                          constraints: BoxConstraints(
                            maxWidth: math.max(
                              0.0,
                              constraints.maxWidth - 64.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Text(
                            _lastSubtitleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: HearthTheme.fontFamily,
                              fontFamilyFallback: HearthTheme.fontFallback,
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                              letterSpacing: 0.2,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 1.5,
                                  offset: Offset(-1.0, -1.0),
                                ),
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 1.5,
                                  offset: Offset(1.0, -1.0),
                                ),
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 1.5,
                                  offset: Offset(-1.0, 1.0),
                                ),
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 1.5,
                                  offset: Offset(1.0, 1.0),
                                ),
                                Shadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.85),
                                  blurRadius: 4.0,
                                  offset: Offset(0.0, 2.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
