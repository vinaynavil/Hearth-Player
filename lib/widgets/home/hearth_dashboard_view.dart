import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/folder.dart';
import '../../models/video.dart';
import '../../theme/hearth_theme.dart';
import '../common/hearth_controls.dart';
import 'hearth_cards.dart';

class HearthDashboardView extends StatelessWidget {
  final bool isScanning;
  final bool isGridView;
  final Video? continueWatchingVideo;
  final List<Video> inProgressVideos;
  final List<Folder> folders;
  final List<Video> allVideos;
  final String searchQuery;
  final VoidCallback? onClearSearch;
  final VoidCallback? onOpenFile;
  final void Function(String filePath, {int? startSeconds}) onPlayVideo;
  final ValueChanged<String> onOpenFolder;

  const HearthDashboardView({super.key, 
    required this.isScanning,
    required this.isGridView,
    required this.continueWatchingVideo,
    required this.inProgressVideos,
    required this.folders,
    required this.allVideos,
    required this.searchQuery,
    this.onClearSearch,
    this.onOpenFile,
    required this.onPlayVideo,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('Search Results', count: allVideos.length),
          const SizedBox(height: 14),
          if (allVideos.isEmpty)
            HearthEmptyCard(
              icon: Symbols.search_off_rounded,
              message: 'No matching videos found in your library',
              action: onClearSearch != null
                  ? HearthButton(
                      label: 'Clear Search',
                      icon: Symbols.close_rounded,
                      onTap: onClearSearch!,
                    )
                  : null,
            )
          else if (isGridView)
            _buildVideoGrid(allVideos)
          else
            _buildHearthTaskRowList(allVideos),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
      children: [
        // 1. MASTER HERO CARD ("CONTINUE WATCHING")
        if (continueWatchingVideo != null) ...[
          HearthMasterHeroCard(
            video: continueWatchingVideo!,
            onResume: () => onPlayVideo(
              continueWatchingVideo!.path,
              startSeconds: continueWatchingVideo!.lastWatchedPosition,
            ),
            onStartOver: () => onPlayVideo(
              continueWatchingVideo!.path,
              startSeconds: 0,
            ),
          ),
          const SizedBox(height: 28),
        ],

        // 2. IN PROGRESS VIDEO CARDS
        if (inProgressVideos.isNotEmpty) ...[
          _buildSectionHeader('In Progress', count: inProgressVideos.length),
          const SizedBox(height: 14),
          if (isGridView)
            _buildVideoGrid(inProgressVideos)
          else
            _buildHearthTaskRowList(inProgressVideos),
          const SizedBox(height: 28),
        ],

        if (continueWatchingVideo == null && inProgressVideos.isEmpty) ...[
          const SizedBox(height: 48),
          HearthEmptyCard(
            icon: Symbols.video_library_rounded,
            message:
                'No videos in progress. Select a folder on the left or click "Open File" above.',
            action: onOpenFile != null
                ? HearthButton(
                    label: 'Open Video File',
                    icon: Symbols.folder_open_rounded,
                    onTap: onOpenFile!,
                  )
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, {int? count, String? subtitle}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: HearthTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        if (count != null) ...[
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
        if (subtitle != null) ...[
          const SizedBox(width: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: HearthTheme.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoGrid(List<Video> videos) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols = math.max(2, (constraints.maxWidth / 275).floor());
        final double width = (constraints.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: videos.map((video) {
            return SizedBox(
              width: width,
              height: 210,
              child: HearthInProgressVideoCard(
                video: video,
                onTap: () => onPlayVideo(
                  video.path,
                  startSeconds: video.lastWatchedPosition > 0
                      ? video.lastWatchedPosition
                      : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Hearth's signature TaskCard horizontal row style (when toggled to List View)
  Widget _buildHearthTaskRowList(List<Video> videos) {
    return Column(
      children: videos
          .map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HearthTaskStyleVideoRow(
                video: v,
                onPlay: () => onPlayVideo(
                  v.path,
                  startSeconds:
                      v.lastWatchedPosition > 0 ? v.lastWatchedPosition : null,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
