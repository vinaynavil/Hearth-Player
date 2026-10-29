import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/hearth_theme.dart';
import '../common/hearth_controls.dart';

class HearthSidebar extends StatefulWidget {
  final bool isCollapsed;
  final String selectedItem;
  final String? activeDirectoryPath;
  final List<Map<String, dynamic>> quickAccessItems;
  final List<Map<String, dynamic>> recentFolders;
  final List<Map<String, dynamic>> drives;
  final VoidCallback onHomeTap;
  final void Function(String path, String name) onDirectorySelected;

  const HearthSidebar({super.key, 
    required this.isCollapsed,
    required this.selectedItem,
    required this.activeDirectoryPath,
    required this.quickAccessItems,
    required this.recentFolders,
    required this.drives,
    required this.onHomeTap,
    required this.onDirectorySelected,
  });

  @override
  State<HearthSidebar> createState() => _HearthSidebarState();
}

class _HearthSidebarState extends State<HearthSidebar> {
  bool _isQuickAccessExpanded = true;
  bool _isRecentExpanded = true;
  bool _isDrivesExpanded = true;
  String? _hoveredKey;
  String? _pressedDriveKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: widget.isCollapsed ? 68 : 244,
      color: HearthTheme.sidebarSurface,
      padding: EdgeInsets.symmetric(
        vertical: 16,
        horizontal: widget.isCollapsed ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: widget.isCollapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          // Scrollable upper sections (Quick Access + Recent)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: widget.isCollapsed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  // Dashboard / Library Home Item
                  _buildNavItem(
                    keyId: 'nav_home',
                    name: 'Home Library',
                    icon: Symbols.home_rounded,
                    isSelected: widget.activeDirectoryPath == null,
                    onTap: widget.onHomeTap,
                  ),
                  const SizedBox(height: 14),

                  // QUICK ACCESS SECTION
                  if (!widget.isCollapsed) ...[
                    _buildSectionHeader(
                      title: 'QUICK ACCESS',
                      isExpanded: _isQuickAccessExpanded,
                      onTap: () => setState(
                        () => _isQuickAccessExpanded = !_isQuickAccessExpanded,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (widget.isCollapsed || _isQuickAccessExpanded)
                    ...widget.quickAccessItems.map((item) {
                      final String name = item['name'] as String;
                      final IconData icon = item['icon'] as IconData;
                      final String path = item['path'] as String;
                      final bool isSelected =
                          widget.activeDirectoryPath == path ||
                              (widget.activeDirectoryPath != null &&
                                  widget.selectedItem == name);
                      return _buildNavItem(
                        keyId: 'qa_$name',
                        name: name,
                        icon: icon,
                        isSelected: isSelected,
                        onTap: () => widget.onDirectorySelected(path, name),
                      );
                    }),

                  const SizedBox(height: 18),

                  // RECENT SECTION
                  if (widget.recentFolders.isNotEmpty) ...[
                    if (!widget.isCollapsed) ...[
                      _buildSectionHeader(
                        title: 'RECENT',
                        isExpanded: _isRecentExpanded,
                        onTap: () => setState(
                          () => _isRecentExpanded = !_isRecentExpanded,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (widget.isCollapsed || _isRecentExpanded)
                      ...widget.recentFolders.map((item) {
                        final String name = item['name'] as String;
                        final IconData icon = item['icon'] as IconData;
                        final String path = item['path'] as String;
                        return _buildNavItem(
                          keyId: 'recent_$path',
                          name: name,
                          icon: icon,
                          isSelected: widget.activeDirectoryPath == path,
                          onTap: () => widget.onDirectorySelected(path, name),
                        );
                      }),
                  ],
                ],
              ),
            ),
          ),

          // DRIVES & VOLUMES SECTION (Pinned cleanly at bottom like Hearth screenshot)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: HearthTheme.subtleBorder),
          ),
          if (!widget.isCollapsed) ...[
            _buildSectionHeader(
              title: 'DRIVES & VOLUMES',
              isExpanded: _isDrivesExpanded,
              onTap: () =>
                  setState(() => _isDrivesExpanded = !_isDrivesExpanded),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.isCollapsed || _isDrivesExpanded)
            ...widget.drives.map(_buildDriveItem),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final String hoverKey = 'hdr_$title';
    final bool isHovered = _hoveredKey == hoverKey;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredKey = hoverKey),
      onExit: (_) => setState(() => _hoveredKey = null),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isHovered
                        ? HearthTheme.textSecondary
                        : HearthTheme.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.0 : -0.25,
                duration: HearthTheme.durationMedium,
                curve: HearthTheme.easeOut,
                child: Icon(
                  Symbols.keyboard_arrow_down_rounded,
                  size: 15,
                  color: isHovered
                      ? HearthTheme.textSecondary
                      : HearthTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String keyId,
    required String name,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return HearthNavButton(
      name: name,
      icon: icon,
      isCollapsed: widget.isCollapsed,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildDriveItem(Map<String, dynamic> drive) {
    final String name = drive['name'] as String;
    final String path = drive['path'] as String;
    final String? freeSpace = drive['freeSpace'] as String?;
    final double? progress = drive['progress'] as double?;
    final bool isSelected = widget.activeDirectoryPath == path;
    final String hoverKey = 'drive_$path';
    final bool isHovered = _hoveredKey == hoverKey;
    final bool isPressed = _pressedDriveKey == hoverKey;

    if (widget.isCollapsed) {
      return Tooltip(
        message: freeSpace != null ? '$name ($freeSpace)' : name,
        child: _buildNavItem(
          keyId: hoverKey,
          name: name,
          icon: Symbols.hard_drive_rounded,
          isSelected: isSelected,
          onTap: () => widget.onDirectorySelected(path, name),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredKey = hoverKey),
      onExit: (_) => setState(() {
        _hoveredKey = null;
        _pressedDriveKey = null;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressedDriveKey = hoverKey),
        onTapUp: (_) => setState(() => _pressedDriveKey = null),
        onTapCancel: () => setState(() => _pressedDriveKey = null),
        onTap: () => widget.onDirectorySelected(path, name),
        child: AnimatedScale(
          scale: isPressed ? 0.98 : 1.0,
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          child: AnimatedContainer(
            duration: HearthTheme.durationMedium,
            curve: HearthTheme.easeOut,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? HearthTheme.accentSubtleFill
                  : (isHovered
                      ? HearthTheme.buttonHover
                      : HearthTheme.cardOverlayFill),
              borderRadius: BorderRadius.circular(HearthTheme.buttonRadius + 2),
              border: Border.all(
                color: isSelected
                    ? HearthTheme.activeBorder
                    : (isHovered
                        ? HearthTheme.hoverBorder
                        : HearthTheme.subtleBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.hard_drive_rounded,
                      size: 15,
                      color: isSelected || isHovered
                          ? HearthTheme.accentHover
                          : HearthTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: HearthTheme.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (freeSpace != null)
                      Text(
                        freeSpace,
                        style: const TextStyle(
                          color: HearthTheme.textMuted,
                          fontSize: 11,
                          fontFeatures: HearthTheme.tabularFigures,
                        ),
                      ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: const Color(0x26FFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        HearthTheme.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
