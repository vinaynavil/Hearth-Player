import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../models/video.dart';
import '../../theme/hearth_theme.dart';
import '../common/hearth_controls.dart';
import 'hearth_cards.dart';

class HearthDirectoryBrowser extends StatelessWidget {
  final String activeDirectoryPath;
  final bool isDirectoryLoading;
  final String? directoryError;
  final List<Directory> dirSubfolders;
  final Map<String, int> dirSubfolderVideoCounts;
  final List<File> dirVideoFiles;
  final List<Video> allDbVideos;
  final bool isGridView;
  final String searchQuery;
  final VoidCallback? onClearSearch;
  final VoidCallback onBackToDashboard;
  final ValueChanged<String> onOpenDirectory;
  final void Function(String path, {int? startSeconds}) onPlayVideo;

  const HearthDirectoryBrowser({
    super.key,
    required this.activeDirectoryPath,
    required this.isDirectoryLoading,
    required this.directoryError,
    required this.dirSubfolders,
    this.dirSubfolderVideoCounts = const {},
    required this.dirVideoFiles,
    required this.allDbVideos,
    required this.isGridView,
    this.searchQuery = '',
    this.onClearSearch,
    required this.onBackToDashboard,
    required this.onOpenDirectory,
    required this.onPlayVideo,
  });

  List<MapEntry<String, String>> _buildBreadcrumbs(String path) {
    final List<String> rawParts = p.split(path);
    final List<MapEntry<String, String>> segments = [];
    String cumulative = '';
    for (int i = 0; i < rawParts.length; i++) {
      final String part = rawParts[i];
      if (part.isEmpty || part == '.') continue;
      if (i == 0) {
        cumulative = part;
        if (RegExp(r'^[A-Za-z]:$').hasMatch(cumulative)) {
          cumulative = '$cumulative${Platform.pathSeparator}';
        }
      } else {
        cumulative = p.join(cumulative, part);
      }
      String displayName = part;
      if (displayName.endsWith(Platform.pathSeparator) ||
          displayName.endsWith('/') ||
          displayName.endsWith(r'\')) {
        displayName = displayName.substring(0, displayName.length - 1);
      }
      segments.add(MapEntry(displayName, cumulative));
    }
    return segments;
  }

  Widget _buildSectionHeader(String singular, int count) {
    final String title = count == 1 ? singular : '${singular}s';
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: HearthTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: HearthTheme.accentSubtleFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HearthTheme.hoverBorder),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: HearthTheme.accentHover,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: HearthTheme.tabularFigures,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String parentPath = Directory(activeDirectoryPath).parent.path;
    final bool canGoUp = parentPath != activeDirectoryPath;
    final List<MapEntry<String, String>> breadcrumbs =
        _buildBreadcrumbs(activeDirectoryPath);

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 32),
      children: [
        // Interactive Segmented Breadcrumb Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: HearthTheme.cardOverlayFill,
            borderRadius: BorderRadius.circular(HearthTheme.cardRadius),
            border: Border.all(color: HearthTheme.subtleBorder),
          ),
          child: Row(
            children: [
              HearthIconButton(
                icon: Symbols.home_rounded,
                tooltip: 'Back to Home Library',
                onTap: onBackToDashboard,
              ),
              if (canGoUp) ...[
                const SizedBox(width: 4),
                HearthIconButton(
                  icon: Symbols.arrow_upward_rounded,
                  tooltip: 'Up One Folder',
                  onTap: () => onOpenDirectory(parentPath),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 18,
                color: HearthTheme.subtleBorder,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < breadcrumbs.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Symbols.chevron_right_rounded,
                              size: 14,
                              color: HearthTheme.textMuted,
                            ),
                          ),
                        _BreadcrumbChip(
                          label: breadcrumbs[i].key,
                          isCurrent: i == breadcrumbs.length - 1,
                          onTap: i == breadcrumbs.length - 1
                              ? null
                              : () => onOpenDirectory(breadcrumbs[i].value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (isDirectoryLoading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(color: HearthTheme.accent),
            ),
          )
        else if (directoryError != null)
          HearthEmptyCard(
            icon: Symbols.error_rounded,
            message: directoryError!,
            action: HearthButton(
              label: canGoUp ? 'Up One Folder' : 'Back to Library',
              icon: Symbols.arrow_back_rounded,
              onTap: canGoUp
                  ? () => onOpenDirectory(parentPath)
                  : onBackToDashboard,
            ),
          )
        else ...[
          if (dirSubfolders.isNotEmpty) ...[
            _buildSectionHeader('Folder', dirSubfolders.length),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final int cols =
                    math.max(2, (constraints.maxWidth / 300).floor());
                final double width =
                    (constraints.maxWidth - (cols - 1) * 14) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: dirSubfolders.map((dir) {
                    return SizedBox(
                      width: width,
                      child: HearthFolderCard(
                        folderName: p.basename(dir.path),
                        videoCount: dirSubfolderVideoCounts[dir.path] ?? 0,
                        onTap: () => onOpenDirectory(dir.path),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 26),
          ],
          _buildSectionHeader('Video', dirVideoFiles.length),
          const SizedBox(height: 12),
          if (dirVideoFiles.isEmpty)
            HearthEmptyCard(
              icon: searchQuery.isNotEmpty
                  ? Symbols.search_off_rounded
                  : Symbols.videocam_off_rounded,
              message: searchQuery.isNotEmpty
                  ? 'No videos matching "$searchQuery" in this folder'
                  : 'No video files in this folder',
              action: searchQuery.isNotEmpty
                  ? (onClearSearch != null
                      ? HearthButton(
                          label: 'Clear Search',
                          icon: Symbols.close_rounded,
                          onTap: onClearSearch!,
                        )
                      : null)
                  : (dirSubfolders.isEmpty
                      ? HearthButton(
                          label: canGoUp ? 'Up One Folder' : 'Back to Library',
                          icon: Symbols.arrow_upward_rounded,
                          onTap: canGoUp
                              ? () => onOpenDirectory(parentPath)
                              : onBackToDashboard,
                        )
                      : null),
            )
          else
            Builder(
              builder: (context) {
                final Map<String, Video> dbMap = {
                  for (final v in allDbVideos) v.path: v,
                };
                final List<Video> mappedVideos = dirVideoFiles.map((file) {
                  return dbMap[file.path] ??
                      Video(
                        id: file.path,
                        path: file.path,
                        title: p.basenameWithoutExtension(file.path),
                        folderPath: file.parent.path,
                        dateAdded: DateTime.now(),
                      );
                }).toList();

                if (isGridView) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final int cols =
                          math.max(2, (constraints.maxWidth / 275).floor());
                      final double width =
                          (constraints.maxWidth - (cols - 1) * 16) / cols;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: mappedVideos.map((v) {
                          return SizedBox(
                            width: width,
                            height: 210,
                            child: HearthInProgressVideoCard(
                              video: v,
                              onTap: () => onPlayVideo(v.path),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                }

                return Column(
                  children: mappedVideos
                      .map(
                        (v) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: HearthTaskStyleVideoRow(
                            video: v,
                            onPlay: () => onPlayVideo(v.path),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ],
    );
  }
}

class _BreadcrumbChip extends StatefulWidget {
  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isCurrent,
    this.onTap,
  });

  @override
  State<_BreadcrumbChip> createState() => _BreadcrumbChipState();
}

class _BreadcrumbChipState extends State<_BreadcrumbChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: HearthTheme.accentSubtleFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: HearthTheme.hoverBorder),
        ),
        child: Text(
          HearthTheme.middleTruncate(widget.label, maxLength: 28),
          style: const TextStyle(
            color: HearthTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: HearthTheme.durationFast,
          curve: HearthTheme.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? HearthTheme.buttonHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? HearthTheme.subtleBorder : Colors.transparent,
            ),
          ),
          child: Text(
            HearthTheme.middleTruncate(widget.label, maxLength: 28),
            style: TextStyle(
              color: _isHovered
                  ? HearthTheme.textPrimary
                  : HearthTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
