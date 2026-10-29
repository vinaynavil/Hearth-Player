import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../models/video.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/hearth_theme.dart';
import '../common/hearth_controls.dart';

class HearthMasterHeroCard extends StatefulWidget {
  final Video video;
  final VoidCallback onResume;
  final VoidCallback onStartOver;

  const HearthMasterHeroCard({super.key, 
    required this.video,
    required this.onResume,
    required this.onStartOver,
  });

  @override
  State<HearthMasterHeroCard> createState() => _HearthMasterHeroCardState();
}

class _HearthMasterHeroCardState extends State<HearthMasterHeroCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Video v = widget.video;
    final int pos = v.lastWatchedPosition;
    final int dur = v.durationSeconds ?? 0;
    final double progress =
        (dur > 0 && pos > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    final int pct = (progress * 100).round();
    final int remaining = math.max(0, dur - pos);
    final String ext = p.extension(v.path).replaceFirst('.', '').toUpperCase();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: HearthTheme.durationMedium,
        curve: HearthTheme.easeOut,
        height: 256,
        decoration: BoxDecoration(
          color: HearthTheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _isHovered ? HearthTheme.hoverBorder : HearthTheme.subtleBorder,
            width: 1.0,
          ),
          boxShadow: HearthTheme.fluentShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Video Thumbnail with subtle zoom on hover
            Positioned.fill(
              child: VideoThumbnailImage(
                video: v,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // Hearth Dark Indigo-to-Transparent Gradient Scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.45, 0.78, 1.0],
                    colors: [
                      Color(0xF20A0D14),
                      Color(0xCC0D1017),
                      Color(0x590D1017),
                      Color(0x260D1017),
                    ],
                  ),
                ),
              ),
            ),

            // Content Foreground
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Badges: CONTINUE WATCHING + Format (MKV/MP4)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HearthTheme.accentSubtleFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: HearthTheme.activeBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.fiber_manual_record_rounded,
                              size: 9,
                              color: HearthTheme.accentHover,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'CONTINUE WATCHING',
                              style: TextStyle(
                                color: HearthTheme.accentHover,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ext.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x26FFFFFF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: HearthTheme.subtleBorder),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 68),
                            child: Text(
                              ext,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HearthTheme.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Video Title with Middle Truncation & Hover Tooltip
                  Tooltip(
                    message: v.title,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      HearthTheme.middleTruncate(v.title, maxLength: 68),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Time & Percentage Metadata
                  Text(
                    dur > 0
                        ? '${formatDuration(pos)} of ${formatDuration(dur)}   •   $pct% watched • ${formatDuration(remaining)} remaining'
                        : 'Duration unknown • $pct% watched',
                    style: const TextStyle(
                      color: HearthTheme.textSecondary,
                      fontSize: 12,
                      fontFeatures: HearthTheme.tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  SizedBox(
                    width: 420,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: const Color(0x28FFFFFF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          HearthTheme.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons: Resume (Primary Accent) & Start Over (Secondary Fluent)
                  Row(
                    children: [
                      HearthButton(
                        icon: Symbols.play_arrow_rounded,
                        label: 'Resume',
                        isPrimary: true,
                        onTap: widget.onResume,
                      ),
                      const SizedBox(width: 10),
                      HearthButton(
                        label: 'Start Over',
                        onTap: widget.onStartOver,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// IN PROGRESS / LIBRARY VIDEO CARD
// Matches Hearth's 4-column thumbnail card structure + Hearth's Fluent borders/hover
// =============================================================================
class HearthInProgressVideoCard extends StatefulWidget {
  final Video video;
  final VoidCallback onTap;

  const HearthInProgressVideoCard({super.key, 
    required this.video,
    required this.onTap,
  });

  @override
  State<HearthInProgressVideoCard> createState() => _HearthInProgressVideoCardState();
}

class _HearthInProgressVideoCardState extends State<HearthInProgressVideoCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb >= 100 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1)} MB';
    }
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb >= 10 ? gb.toStringAsFixed(1) : gb.toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ThumbnailService.instance.durationRevision,
      builder: (context, _, child) {
        final Video v = widget.video;
        final String ext = p.extension(v.path).replaceFirst('.', '').toUpperCase();
        final int pos = v.lastWatchedPosition;
        final int dur = v.durationSeconds ??
            ThumbnailService.instance.peekDuration(v.id) ??
            0;
        final double progress =
            (dur > 0 && pos > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;
        final int pct = (progress * 100).round();
        final int leftSec = math.max(0, dur - pos);

        return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          child: AnimatedContainer(
            duration: HearthTheme.durationMedium,
            curve: HearthTheme.easeOut,
            decoration: BoxDecoration(
              color: _isHovered
                  ? HearthTheme.cardSurfaceHover
                  : HearthTheme.cardSurface,
              borderRadius: BorderRadius.circular(HearthTheme.cardRadius),
              border: Border.all(
                color: _isHovered
                    ? HearthTheme.hoverBorder
                    : HearthTheme.subtleBorder,
              ),
              boxShadow: HearthTheme.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Viewport
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoThumbnailImage(
                        video: v,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black
                            .withValues(alpha: _isHovered ? 0.18 : 0.30),
                      ),

                      // Top-left format badge (MKV / MP4)
                      if (ext.isNotEmpty)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB80E0E12),
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: HearthTheme.subtleBorder),
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 68),
                              child: Text(
                                ext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: HearthTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Bottom-right Duration Badge
                      if (dur > 0)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xCC0E0E12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              formatDuration(dur),
                              style: const TextStyle(
                                color: HearthTheme.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: HearthTheme.tabularFigures,
                              ),
                            ),
                          ),
                        ),

                      // Bottom Progress Bar
                      if (progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3.5,
                            backgroundColor: const Color(0x33FFFFFF),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              HearthTheme.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Card Footer: Title + Remaining / % Watched
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: v.title,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          HearthTheme.middleTruncate(v.title, maxLength: 44),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HearthTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress > 0
                            ? '${formatDuration(leftSec)} left • $pct% watched'
                            : ((v.fileSizeBytes ?? 0) > 0
                                ? _formatFileSize(v.fileSizeBytes!)
                                : p.basename(v.folderPath)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HearthTheme.textMuted,
                          fontSize: 11.5,
                          fontFeatures: HearthTheme.tabularFigures,
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
      },
    );
  }
}

// =============================================================================
// HEARTH TASK-STYLE HORIZONTAL VIDEO ROW (Used when List View is active)
// Mirrors Hearth's TaskCard row layout from screenshot 2
// =============================================================================
class HearthTaskStyleVideoRow extends StatefulWidget {
  final Video video;
  final VoidCallback onPlay;

  const HearthTaskStyleVideoRow({super.key, 
    required this.video,
    required this.onPlay,
  });

  @override
  State<HearthTaskStyleVideoRow> createState() => _HearthTaskStyleVideoRowState();
}

class _HearthTaskStyleVideoRowState extends State<HearthTaskStyleVideoRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Video v = widget.video;
    final String ext = p.extension(v.path).replaceFirst('.', '').toUpperCase();
    final int pos = v.lastWatchedPosition;
    final int dur = v.durationSeconds ?? 0;
    final double progress =
        (dur > 0 && pos > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPlay,
        child: AnimatedScale(
          scale: _isPressed ? 0.99 : 1.0,
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          child: AnimatedContainer(
            duration: HearthTheme.durationMedium,
            curve: HearthTheme.easeOut,
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isHovered
                  ? HearthTheme.cardSurfaceHover
                  : HearthTheme.cardSurface,
              borderRadius: BorderRadius.circular(HearthTheme.cardRadius),
              border: Border.all(
                color: _isHovered
                    ? HearthTheme.hoverBorder
                    : HearthTheme.subtleBorder,
              ),
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    // HEARTH MKV / File Type Purple Icon Badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            HearthTheme.accentHover,
                            HearthTheme.accentPressed,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Symbols.play_arrow_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                          if (ext.isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 34),
                              child: Text(
                                ext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Metadata Row
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: p.basename(v.path),
                            waitDuration: const Duration(milliseconds: 500),
                            child: Text(
                              HearthTheme.middleTruncate(
                                p.basename(v.path),
                                maxLength: 68,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HearthTheme.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (dur > 0) ...[
                                const Icon(
                                  Symbols.schedule_rounded,
                                  size: 13,
                                  color: HearthTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pos > 0
                                      ? '${formatDuration(pos)} / ${formatDuration(dur)}'
                                      : formatDuration(dur),
                                  style: const TextStyle(
                                    color: HearthTheme.textSecondary,
                                    fontSize: 11.5,
                                    fontFeatures: HearthTheme.tabularFigures,
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Text(
                                  v.folderPath,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: HearthTheme.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right-side HEARTH Action ToolButton
                    HearthIconButton(
                      icon: Symbols.play_arrow_rounded,
                      tooltip: 'Play Video',
                      isAccentFilled: progress > 0,
                      onTap: widget.onPlay,
                    ),
                  ],
                ),

                // Bottom progress bar (like active download in Hearth)
                if (progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          HearthTheme.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FOLDERS & COLLECTIONS CARD
// =============================================================================
class HearthFolderCard extends StatefulWidget {
  final String folderName;
  final int videoCount;
  final VoidCallback onTap;

  const HearthFolderCard({super.key, 
    required this.folderName,
    required this.videoCount,
    required this.onTap,
  });

  @override
  State<HearthFolderCard> createState() => _HearthFolderCardState();
}

class _HearthFolderCardState extends State<HearthFolderCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          child: AnimatedContainer(
            duration: HearthTheme.durationMedium,
            curve: HearthTheme.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: _isHovered
                  ? HearthTheme.cardSurfaceHover
                  : HearthTheme.cardSurface,
              borderRadius: BorderRadius.circular(HearthTheme.cardRadius),
              border: Border.all(
                color: _isHovered
                    ? HearthTheme.hoverBorder
                    : HearthTheme.subtleBorder,
              ),
              boxShadow: HearthTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HearthTheme.accentSubtleFill,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: HearthTheme.hoverBorder),
                  ),
                  child: const Icon(
                    Symbols.folder_rounded,
                    size: 20,
                    color: HearthTheme.accentHover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.folderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HearthTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        HearthTheme.pluralize(widget.videoCount, 'video'),
                        style: const TextStyle(
                          color: HearthTheme.textMuted,
                          fontSize: 11.5,
                          fontFeatures: HearthTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.chevron_right_rounded,
                  size: 18,
                  color: _isHovered
                      ? HearthTheme.accentHover
                      : HearthTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

