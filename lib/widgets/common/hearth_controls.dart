import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/video.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/hearth_theme.dart';

class HearthEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const HearthEmptyCard({super.key, 
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: HearthTheme.cardOverlayFill, // QColor(255, 255, 255, 13)
          borderRadius: BorderRadius.circular(HearthTheme.cardRadius),
          border: Border.all(color: HearthTheme.subtleBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: HearthTheme.accent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD8D8D8), // QColor(216, 216, 216)
                fontSize: 12.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Fluent PushButton / PrimaryPushButton with Hearth's hover & press physics
class HearthButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final bool isPrimary;
  final bool isCompact;
  final VoidCallback onTap;

  const HearthButton({super.key, 
    this.icon,
    required this.label,
    this.isPrimary = false,
    this.isCompact = false,
    required this.onTap,
  });

  @override
  State<HearthButton> createState() => _HearthButtonState();
}

class _HearthButtonState extends State<HearthButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (widget.isPrimary) {
      bg = _isPressed
          ? HearthTheme.accentPressed
          : (_isHovered ? HearthTheme.accentHover : HearthTheme.accent);
    } else {
      bg = _isPressed
          ? HearthTheme.buttonPressed
          : (_isHovered ? HearthTheme.buttonHover : HearthTheme.buttonRest);
    }

    final Color fg =
        widget.isPrimary ? const Color(0xFF0E0E12) : HearthTheme.textPrimary;

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
          scale: _isPressed ? 0.97 : 1.0,
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          child: AnimatedContainer(
            duration: HearthTheme.durationMedium,
            curve: HearthTheme.easeOut,
            height: widget.isCompact ? 32 : 36,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(HearthTheme.buttonRadius),
              border: Border.all(
                color: widget.isPrimary
                    ? const Color(0x40FFFFFF)
                    : (_isHovered
                        ? HearthTheme.hoverBorder
                        : HearthTheme.subtleBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: fg),
                  const SizedBox(width: 7),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: widget.isCompact ? 12 : 13,
                    fontWeight:
                        widget.isPrimary ? FontWeight.w700 : FontWeight.w600,
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

/// Fluent ToolButton with Hearth's soft lavender active fill
class HearthIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isAccentFilled;
  final VoidCallback onTap;

  const HearthIconButton({super.key, 
    required this.icon,
    required this.tooltip,
    this.isAccentFilled = false,
    required this.onTap,
  });

  @override
  State<HearthIconButton> createState() => _HearthIconButtonState();
}

class _HearthIconButtonState extends State<HearthIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (widget.isAccentFilled) {
      bg = _isHovered ? HearthTheme.accentHover : HearthTheme.accent;
    } else {
      bg = _isPressed
          ? HearthTheme.buttonPressed
          : (_isHovered ? HearthTheme.buttonHover : HearthTheme.buttonRest);
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
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
            scale: _isPressed ? 0.95 : 1.0,
            duration: HearthTheme.durationFast,
            curve: HearthTheme.easeOut,
            child: AnimatedContainer(
              duration: HearthTheme.durationFast,
              curve: HearthTheme.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(HearthTheme.buttonRadius),
                border: Border.all(
                  color: widget.isAccentFilled
                      ? Colors.transparent
                      : HearthTheme.subtleBorder,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 17,
                color: widget.isAccentFilled
                    ? const Color(0xFF0E0E12)
                    : HearthTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SegmentedToggleToolWidget button item (matches Hearth's top-left filter pills)
class HearthSegItem extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const HearthSegItem({super.key, 
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<HearthSegItem> createState() => _HearthSegItemState();
}

class _HearthSegItemState extends State<HearthSegItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
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
            scale: _isPressed ? 0.97 : 1.0,
            duration: HearthTheme.durationFast,
            curve: HearthTheme.easeOut,
            child: AnimatedContainer(
              duration: HearthTheme.durationFast,
              curve: HearthTheme.easeOut,
              width: 30,
              height: 26,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? HearthTheme.accent
                    : (_isHovered ? HearthTheme.buttonHover : Colors.transparent),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected
                    ? const Color(0xFF0E0E12)
                    : HearthTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fluent Sidebar Navigation Button with left indicator pill & press scale
class HearthNavButton extends StatefulWidget {
  final String name;
  final IconData icon;
  final bool isCollapsed;
  final bool isSelected;
  final VoidCallback onTap;

  const HearthNavButton({super.key, 
    required this.name,
    required this.icon,
    required this.isCollapsed,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<HearthNavButton> createState() => _HearthNavButtonState();
}

class _HearthNavButtonState extends State<HearthNavButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    if (widget.isSelected) {
      bg = HearthTheme.accentSubtleFill;
    } else if (_isPressed) {
      bg = HearthTheme.buttonPressed;
    } else if (_isHovered) {
      bg = HearthTheme.buttonHover;
    }

    final Widget content = MouseRegion(
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
          scale: _isPressed ? 0.97 : 1.0,
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          child: AnimatedContainer(
            duration: HearthTheme.durationFast,
            curve: HearthTheme.easeOut,
            margin: const EdgeInsets.only(bottom: 4),
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected
                    ? HearthTheme.activeBorder
                    : Colors.transparent,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Fluent left vertical accent pill when active
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 3.5,
                      height: 18,
                      decoration: BoxDecoration(
                        color: HearthTheme.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isCollapsed ? 0 : 12,
                  ),
                  child: widget.isCollapsed
                      ? Center(
                          child: Icon(
                            widget.icon,
                            size: 19,
                            color: widget.isSelected
                                ? HearthTheme.accentHover
                                : HearthTheme.textSecondary,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              widget.icon,
                              size: 18,
                              color: widget.isSelected
                                  ? HearthTheme.accentHover
                                  : (_isHovered
                                      ? Colors.white
                                      : HearthTheme.textSecondary),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                widget.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.isSelected || _isHovered
                                      ? Colors.white
                                      : HearthTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: widget.isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
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

    if (widget.isCollapsed) {
      return Tooltip(message: widget.name, child: content);
    }
    return content;
  }
}

/// Windows 11 Caption Control Button (Minimize, Maximize, Close)
class WindowCaptionButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final bool isClose;
  final VoidCallback onTap;

  const WindowCaptionButton({super.key, 
    required this.icon,
    this.iconSize = 16,
    this.isClose = false,
    required this.onTap,
  });

  @override
  State<WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: HearthTheme.easeOut,
          width: 42,
          height: 34,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isClose
                    ? const Color(0xFFE81123)
                    : HearthTheme.buttonHover)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered ? Colors.white : HearthTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Resolves and displays real video thumbnails from ThumbnailService
class VideoThumbnailImage extends StatefulWidget {
  final Video video;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final int? cacheWidth;

  const VideoThumbnailImage({
    super.key, 
    required this.video,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth = 640,
  });

  @override
  State<VideoThumbnailImage> createState() => _VideoThumbnailImageState();
}

class _VideoThumbnailImageState extends State<VideoThumbnailImage> {
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.path != widget.video.path ||
        oldWidget.video.thumbnailPath != widget.video.thumbnailPath) {
      if (_resolvedPath != null) {
        FileImage(File(_resolvedPath!)).evict();
      }
      _resolveThumbnail();
    }
  }

  void _resolveThumbnail() {
    final String? initial = widget.video.thumbnailPath ??
        ThumbnailService.instance.peekResolved(widget.video.path);
    if (initial != null && File(initial).existsSync()) {
      _resolvedPath = initial;
      if ((widget.video.durationSeconds ?? 0) <= 0 &&
          ThumbnailService.instance.peekDuration(widget.video.id) == null) {
        unawaited(
          ThumbnailService.instance.ensureDurationResolved(widget.video),
        );
      }
      return;
    }
    ThumbnailService.instance
        .resolveOrGenerateAndUpdateDb(widget.video)
        .then((generated) {
      if ((widget.video.durationSeconds ?? 0) <= 0 &&
          ThumbnailService.instance.peekDuration(widget.video.id) == null) {
        unawaited(
          ThumbnailService.instance.ensureDurationResolved(widget.video),
        );
      }
      if (mounted && generated != null && File(generated).existsSync()) {
        setState(() => _resolvedPath = generated);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValidThumbnail =
        _resolvedPath != null && File(_resolvedPath!).existsSync();

    return AnimatedSwitcher(
      duration: HearthTheme.durationMedium,
      switchInCurve: HearthTheme.easeOut,
      switchOutCurve: HearthTheme.easeOut,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: hasValidThumbnail
          ? Image.file(
              File(_resolvedPath!),
              key: ValueKey<String>(_resolvedPath!),
              width: double.infinity,
              height: double.infinity,
              fit: widget.fit,
              alignment: widget.alignment,
              cacheWidth: widget.cacheWidth,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          : KeyedSubtree(
              key: const ValueKey<String>('thumbnail_fallback'),
              child: _buildFallback(),
            ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C22),
            Color(0xFF111115),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Symbols.movie_rounded,
          size: 32,
          color: Color(0x335874EE),
        ),
      ),
    );
  }
}

String formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '00:00';
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String mm = minutes.toString().padLeft(2, '0');
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final String hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
  return '$mm:$ss';
}