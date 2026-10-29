import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart' hide WindowCaptionButton;

import '../../models/sort_options.dart';
import '../../theme/hearth_theme.dart';
import '../../utils/app_env.dart';
import '../common/hearth_controls.dart';

class HearthTopBar extends StatefulWidget {
  final String? activeDirectoryPath;
  final bool isGridView;
  final bool isScanning;
  final SortField selectedSortField;
  final SortDirection selectedSortDirection;
  final ValueChanged<SortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onResetDirectory;
  final ValueChanged<bool> onViewModeChanged;
  final VoidCallback onOpenFolder;
  final FocusNode? searchFocusNode;
  final String? searchQuery;

  const HearthTopBar({super.key, 
    required this.activeDirectoryPath,
    required this.isGridView,
    required this.isScanning,
    required this.selectedSortField,
    required this.selectedSortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.onSearchChanged,
    required this.onResetDirectory,
    required this.onViewModeChanged,
    required this.onOpenFolder,
    this.searchFocusNode,
    this.searchQuery,
  });

  @override
  State<HearthTopBar> createState() => _HearthTopBarState();
}

class _HearthTopBarState extends State<HearthTopBar> with WindowListener {
  final TextEditingController _searchController = TextEditingController();
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.searchFocusNode ?? (_internalFocusNode ??= FocusNode());

  bool _isSearchFocused = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((val) {
      if (mounted) {
        setState(() => _isMaximized = val);
      }
    });
    _effectiveFocusNode.addListener(_onFocusChange);
    if (widget.searchQuery != null) {
      _searchController.text = widget.searchQuery!;
    }
  }

  void _onFocusChange() {
    if (mounted && _isSearchFocused != _effectiveFocusNode.hasFocus) {
      setState(() => _isSearchFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(covariant HearthTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFocusNode != widget.searchFocusNode) {
      oldWidget.searchFocusNode?.removeListener(_onFocusChange);
      _effectiveFocusNode.addListener(_onFocusChange);
    }
    if (widget.searchQuery != null && widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery!;
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.searchFocusNode?.removeListener(_onFocusChange);
    _internalFocusNode?.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _isMaximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _isMaximized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 52,
        color: HearthTheme.topBarSurface,
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Exact search width formula from Hearth's main_window.py:
            // w = min(360, tb.width() - 300); w = max(200, w)
            final double searchWidth =
                math.max(200.0, math.min(380.0, constraints.maxWidth - 420.0));

            return Row(
              children: [
                // App Logo & Title
                GestureDetector(
                  onTap: widget.onResetDirectory,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _HearthBrandLogo(size: 30),
                        const SizedBox(width: 10),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16.5,
                              height: 1.0,
                              color: HearthTheme.accent,
                            ),
                            children: [
                              TextSpan(
                                text: 'Hearth',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.15,
                                ),
                              ),
                              TextSpan(
                                text: ' Player',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (AppEnv.isWorkspaceBuild) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HearthTheme.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: HearthTheme.accent.withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'DEV',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                height: 1.1,
                                color: HearthTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Centered SearchLineEdit (Hearth style)
                Focus(
                  onFocusChange: (focused) =>
                      setState(() => _isSearchFocused = focused),
                  child: AnimatedContainer(
                    duration: HearthTheme.durationMedium,
                    curve: HearthTheme.easeOut,
                    width: searchWidth,
                    height: 33,
                    decoration: BoxDecoration(
                      color: _isSearchFocused
                          ? const Color(0x24FFFFFF)
                          : HearthTheme.buttonRest,
                      borderRadius:
                          BorderRadius.circular(HearthTheme.buttonRadius),
                      border: Border.all(
                        color: _isSearchFocused
                            ? HearthTheme.accent
                            : HearthTheme.subtleBorder,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _effectiveFocusNode,
                            onChanged: widget.onSearchChanged,
                            style: const TextStyle(
                              color: HearthTheme.textPrimary,
                              fontSize: 12.5,
                            ),
                            cursorColor: HearthTheme.accent,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Search videos in current folder...',
                              hintStyle: TextStyle(
                                color: HearthTheme.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                widget.onSearchChanged('');
                                setState(() {});
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Symbols.close_rounded,
                                  size: 15,
                                  color: HearthTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        Icon(
                          Symbols.search_rounded,
                          size: 16,
                          color: _isSearchFocused
                              ? HearthTheme.accent
                              : HearthTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Open File button
                HearthButton(
                  icon: Symbols.file_open_rounded,
                  label: 'Open File',
                  isCompact: true,
                  onTap: widget.onOpenFolder,
                ),
                const SizedBox(width: 8),

                // Sort DropDownToolButton (Hearth sort menu style)
                _buildSortMenuButton(),
                const SizedBox(width: 8),

                // SegmentedToggleToolWidget (Grid vs List)
                Container(
                  height: 32,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: HearthTheme.buttonRest,
                    borderRadius:
                        BorderRadius.circular(HearthTheme.buttonRadius),
                    border: Border.all(color: HearthTheme.subtleBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HearthSegItem(
                        icon: Symbols.view_list_rounded,
                        tooltip: 'List View',
                        isSelected: !widget.isGridView,
                        onTap: () => widget.onViewModeChanged(false),
                      ),
                      const SizedBox(width: 2),
                      HearthSegItem(
                        icon: Symbols.grid_view_rounded,
                        tooltip: 'Grid View',
                        isSelected: widget.isGridView,
                        onTap: () => widget.onViewModeChanged(true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Native-style Windows Caption Buttons
                WindowCaptionButton(
                  icon: Symbols.remove_rounded,
                  onTap: () => windowManager.minimize(),
                ),
                WindowCaptionButton(
                  icon: _isMaximized
                      ? Symbols.filter_none_rounded
                      : Symbols.check_box_outline_blank_rounded,
                  iconSize: _isMaximized ? 12 : 13,
                  onTap: () async {
                    if (_isMaximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                WindowCaptionButton(
                  icon: Symbols.close_rounded,
                  isClose: true,
                  onTap: () => windowManager.close(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortMenuButton() {
    return PopupMenuButton<dynamic>(
      tooltip: 'Sort Videos',
      offset: const Offset(0, 38),
      color: const Color(0xF518181C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HearthTheme.cardRadius),
        side: const BorderSide(color: HearthTheme.subtleBorder),
      ),
      itemBuilder: (context) => [
        _buildRadioItem(
          label: 'By Date Added',
          icon: Symbols.schedule_rounded,
          selected: widget.selectedSortField == SortField.dateAdded,
          onTap: () => widget.onSortFieldChanged(SortField.dateAdded),
        ),
        _buildRadioItem(
          label: 'By Name',
          icon: Symbols.sort_by_alpha_rounded,
          selected: widget.selectedSortField == SortField.name,
          onTap: () => widget.onSortFieldChanged(SortField.name),
        ),
        _buildRadioItem(
          label: 'By Duration',
          icon: Symbols.timer_rounded,
          selected: widget.selectedSortField == SortField.duration,
          onTap: () => widget.onSortFieldChanged(SortField.duration),
        ),
        _buildRadioItem(
          label: 'By File Size',
          icon: Symbols.hard_drive_rounded,
          selected: widget.selectedSortField == SortField.size,
          onTap: () => widget.onSortFieldChanged(SortField.size),
        ),
        const PopupMenuDivider(height: 8),
        _buildRadioItem(
          label: 'Ascending',
          icon: Symbols.arrow_upward_rounded,
          selected: widget.selectedSortDirection == SortDirection.ascending,
          onTap: () => widget.onSortDirectionChanged(SortDirection.ascending),
        ),
        _buildRadioItem(
          label: 'Descending',
          icon: Symbols.arrow_downward_rounded,
          selected: widget.selectedSortDirection == SortDirection.descending,
          onTap: () => widget.onSortDirectionChanged(SortDirection.descending),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: HearthTheme.buttonRest,
          borderRadius: BorderRadius.circular(HearthTheme.buttonRadius),
          border: Border.all(color: HearthTheme.subtleBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/layout_selector.svg',
              width: 15,
              height: 15,
              colorFilter: const ColorFilter.mode(
                HearthTheme.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Symbols.keyboard_arrow_down_rounded,
              size: 15,
              color: HearthTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<dynamic> _buildRadioItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return PopupMenuItem<dynamic>(
      height: 36,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? HearthTheme.accent : Colors.transparent,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: 16,
            color: selected ? HearthTheme.accent : HearthTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : HearthTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _HearthBrandLogo extends StatelessWidget {
  final double size;

  const _HearthBrandLogo({this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0994E6), // Bright cyan-blue top-left
            Color(0xFF2855D8), // Mid royal blue
            Color(0xFF4123C4), // Deep indigo-violet bottom-right
          ],
          stops: [0.0, 0.52, 1.0],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2855D8).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: const _HearthStarPlayPainter(),
      ),
    );
  }
}

class _HearthStarPlayPainter extends CustomPainter {
  const _HearthStarPlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double outerR = size.width * 0.39; // Tip distance from center
    final double innerR = size.width * 0.115; // Concave pinch control distance

    // 1. Build 4-pointed concave sparkle star path
    final Path starPath = Path()
      ..moveTo(cx, cy - outerR) // Top tip
      ..quadraticBezierTo(cx + innerR, cy - innerR, cx + outerR, cy) // Right tip
      ..quadraticBezierTo(cx + innerR, cy + innerR, cx, cy + outerR) // Bottom tip
      ..quadraticBezierTo(cx - innerR, cy + innerR, cx - outerR, cy) // Left tip
      ..quadraticBezierTo(cx - innerR, cy - innerR, cx, cy - outerR) // Back to top
      ..close();

    // Subtle soft shadow behind the white star
    canvas.drawShadow(
      starPath.shift(const Offset(0, 0.5)),
      const Color(0x66000000),
      2.0,
      true,
    );

    // Fill white star
    final Paint starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(starPath, starPaint);

    // 2. Draw rounded deep-violet play triangle centered inside the star
    final double triHalfH = size.height * 0.105;
    final double triLeftX = cx - size.width * 0.062;
    final double triRightX = cx + size.width * 0.095;
    final double cornerR = size.width * 0.024;

    final Offset p1 = Offset(triLeftX, cy - triHalfH); // Top-left vertex
    final Offset p2 = Offset(triRightX, cy); // Right tip vertex
    final Offset p3 = Offset(triLeftX, cy + triHalfH); // Bottom-left vertex

    final Path playPath = _buildRoundedTriangle(p1, p2, p3, cornerR);
    final Paint playPaint = Paint()
      ..color = const Color(0xFF440CD2)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(playPath, playPaint);
  }

  Path _buildRoundedTriangle(Offset p1, Offset p2, Offset p3, double radius) {
    final List<Offset> pts = [p1, p2, p3];
    final Path path = Path();

    for (int i = 0; i < 3; i++) {
      final Offset prev = pts[(i + 2) % 3];
      final Offset curr = pts[i];
      final Offset next = pts[(i + 1) % 3];

      final Offset v1 = (prev - curr);
      final Offset v2 = (next - curr);
      final double len1 = v1.distance;
      final double len2 = v2.distance;
      final double r = math.min(radius, math.min(len1, len2) * 0.35);

      final Offset start = curr + (v1 / len1) * r;
      final Offset end = curr + (v2 / len2) * r;

      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
