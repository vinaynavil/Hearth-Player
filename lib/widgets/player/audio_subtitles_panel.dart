import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';

import '../../theme/hearth_theme.dart';

/// Flyout settings panel for switching audio streams and subtitle tracks.
class AudioSubtitlesPanel extends StatelessWidget {
  final bool isVisible;
  final Tracks tracks;
  final Track activeTrack;
  final ValueChanged<AudioTrack> onAudioTrackSelected;
  final ValueChanged<SubtitleTrack> onSubtitleTrackSelected;
  final VoidCallback onLoadSubtitleFile;
  final VoidCallback? onPanelHoverEnter;
  final VoidCallback? onPanelHoverExit;
  final ui.Image? snapshotImage;
  final GlobalKey? panelKey;

  const AudioSubtitlesPanel({
    super.key,
    required this.isVisible,
    required this.tracks,
    required this.activeTrack,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
    required this.onLoadSubtitleFile,
    this.onPanelHoverEnter,
    this.onPanelHoverExit,
    this.snapshotImage,
    this.panelKey,
  });

  String _normalizeLanguageName(String? lang) {
    if (lang == null || lang.trim().isEmpty) return 'Unknown';
    final lower = lang.toLowerCase().trim();
    const map = {
      'eng': 'English',
      'en': 'English',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'kor': 'Korean',
      'ko': 'Korean',
      'chi': 'Chinese',
      'zho': 'Chinese',
      'zh': 'Chinese',
      'rus': 'Russian',
      'ru': 'Russian',
      'por': 'Portuguese',
      'pt': 'Portuguese',
      'ara': 'Arabic',
      'ar': 'Arabic',
    };
    if (map.containsKey(lower)) {
      return map[lower]!;
    }
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _getAudioTrackTitle(AudioTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'Disabled';
    if (track.title != null && track.title!.trim().isNotEmpty) {
      return track.title!.trim();
    }
    if (track.language != null && track.language!.trim().isNotEmpty) {
      return _normalizeLanguageName(track.language);
    }
    return 'Track ${track.id}';
  }

  String _getAudioTrackDetails(AudioTrack track) {
    final parts = <String>[];
    if (track.codec != null && track.codec!.trim().isNotEmpty) {
      final String c = track.codec!.toUpperCase().trim();
      if (c.contains('EAC3') || c.contains('E-AC-3')) {
        parts.add('EAC3');
      } else if (c.contains('AC3') || c.contains('A_AC3')) {
        parts.add('AC3');
      } else if (c.contains('AAC')) {
        parts.add('AAC');
      } else if (c.contains('DTS')) {
        parts.add('DTS');
      } else if (c.contains('OPUS')) {
        parts.add('Opus');
      } else if (c.contains('FLAC')) {
        parts.add('FLAC');
      } else if (c.contains('MP3')) {
        parts.add('MP3');
      } else {
        parts.add(c);
      }
    }
    final String rawCh = (track.channels ?? '').toLowerCase().trim();
    final RegExp digitRegex = RegExp(r'\d+');
    final String? digitMatch = digitRegex.firstMatch(rawCh)?.group(0);
    final int? chCount = digitMatch != null ? int.tryParse(digitMatch) : null;

    if (rawCh.contains('5.1') || chCount == 6) {
      parts.add('5.1');
    } else if (rawCh.contains('7.1') || chCount == 8) {
      parts.add('7.1');
    } else if (rawCh.contains('stereo') || chCount == 2) {
      parts.add('Stereo');
    } else if (rawCh.contains('mono') || chCount == 1) {
      parts.add('Mono');
    } else if (chCount != null && chCount > 0) {
      parts.add('$chCount ch');
    } else if (rawCh.isNotEmpty) {
      parts.add(track.channels!.trim());
    } else {
      if (parts.isEmpty) {
        parts.add('Stereo');
      }
    }
    return parts.join(' ');
  }

  String _getSubtitleTrackTitle(SubtitleTrack track) {
    if (track.id == 'no' || track.id == 'auto') return 'Off';
    if (track.title != null && track.title!.trim().isNotEmpty) {
      return track.title!.trim();
    }
    if (track.language != null && track.language!.trim().isNotEmpty) {
      return _normalizeLanguageName(track.language);
    }
    return 'Subtitle ${track.id}';
  }

  String? _getSubtitleTrackTag(SubtitleTrack track) {
    if (track.id == 'no' || track.id == 'auto') return null;
    final List<String> tags = [];
    final String title = (track.title ?? '').toLowerCase();
    final String codec = (track.codec ?? '').toLowerCase();
    if (title.contains('cc') || title.contains('sdh')) {
      tags.add('[CC]');
    } else if (track.image == true || codec.contains('pgs') || title.contains('pgs')) {
      tags.add('[PGS]');
    } else if (codec.contains('vobsub') || title.contains('vobsub')) {
      tags.add('[VobSub]');
    }
    return tags.isNotEmpty ? tags.join(' ') : null;
  }

  @override
  Widget build(BuildContext context) {
    final realAudioTracks = tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    final realSubtitleTracks = tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();

    return RepaintBoundary(
      key: panelKey,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: isVisible ? HearthTheme.durationOverlay : HearthTheme.durationFast,
              curve: HearthTheme.easeOut,
              child: AnimatedScale(
                scale: isVisible ? 1.0 : 0.95,
                alignment: Alignment.topRight,
                duration: isVisible ? HearthTheme.durationOverlay : HearthTheme.durationFast,
                curve: HearthTheme.easeOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      if (snapshotImage != null)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: ImageFiltered(
                              imageFilter:
                                  ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: RawImage(
                                image: snapshotImage,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: 440,
                        decoration: BoxDecoration(
                          color: Colors.black
                              .withValues(alpha: snapshotImage != null ? 0.82 : 0.86),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: HearthTheme.subtleBorder,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT COLUMN: AUDIO
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'AUDIO',
                                    style: TextStyle(
                                      color: Color(0xFFA1A1AA),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 270),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (realAudioTracks.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 4,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: const [
                                                  Text(
                                                    'Default Audio',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Stereo',
                                                    style: TextStyle(
                                                      color: Color(0xFFA1A1AA),
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            ...realAudioTracks.map((track) {
                                              final bool isSelected =
                                                  activeTrack.audio.id ==
                                                          track.id ||
                                                      (activeTrack.audio.id ==
                                                              'auto' &&
                                                          realAudioTracks
                                                              .isNotEmpty &&
                                                          realAudioTracks
                                                                  .first.id ==
                                                              track.id);
                                              final String title =
                                                  _getAudioTrackTitle(track);
                                              final String details =
                                                  _getAudioTrackDetails(track);

                                              return InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                onTap: () =>
                                                    onAudioTrackSelected(track),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 7,
                                                    horizontal: 2,
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (isSelected)
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                            right: 8,
                                                            top: 2,
                                                          ),
                                                          child: Icon(
                                                            Symbols.check_rounded,
                                                            color: Colors.white,
                                                            size: 16,
                                                          ),
                                                        )
                                                      else
                                                        const SizedBox(
                                                            width: 24),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              HearthTheme.middleTruncate(title, maxLength: 36),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.white,
                                                                fontSize: 13.5,
                                                                fontWeight:
                                                                    isSelected
                                                                        ? FontWeight
                                                                            .w700
                                                                        : FontWeight
                                                                            .w600,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              details,
                                                              style:
                                                                  const TextStyle(
                                                                color: Color(
                                                                    0xFFA1A1AA),
                                                                fontSize: 11.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // VERTICAL DIVIDER
                            Container(
                              width: 1.5,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),

                            // RIGHT COLUMN: SUBTITLES
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'SUBTITLES',
                                    style: TextStyle(
                                      color: Color(0xFFA1A1AA),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 270),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 1. "Off" option
                                          Builder(
                                            builder: (context) {
                                              final bool isOffSelected =
                                                  activeTrack.subtitle.id ==
                                                          'no' ||
                                                      (activeTrack.subtitle
                                                                  .id ==
                                                              'auto' &&
                                                          (realSubtitleTracks
                                                                  .isEmpty ||
                                                              activeTrack
                                                                      .subtitle
                                                                      .id ==
                                                                  'no'));
                                              return InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                onTap: () =>
                                                    onSubtitleTrackSelected(
                                                        SubtitleTrack.no()),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 7,
                                                    horizontal: 2,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      if (isOffSelected)
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  right: 8),
                                                          child: Icon(
                                                            Symbols.check_rounded,
                                                            color: Colors.white,
                                                            size: 16,
                                                          ),
                                                        )
                                                      else
                                                        const SizedBox(
                                                            width: 24),
                                                      const Text(
                                                        'Off',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),

                                          // 2. Real Subtitle tracks
                                          ...realSubtitleTracks.map((track) {
                                            final bool isSelected =
                                                activeTrack.subtitle.id ==
                                                    track.id;
                                            final String title =
                                                _getSubtitleTrackTitle(track);
                                            final String? tag =
                                                _getSubtitleTrackTag(track);

                                            return InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () =>
                                                  onSubtitleTrackSelected(
                                                      track),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 7,
                                                  horizontal: 2,
                                                ),
                                                child: Row(
                                                  children: [
                                                    if (isSelected)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 8),
                                                        child: Icon(
                                                          Symbols.check_rounded,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                      )
                                                    else
                                                      const SizedBox(width: 24),
                                                    Expanded(
                                                      child: Text(
                                                        HearthTheme.middleTruncate(
                                                          tag != null
                                                              ? '$title $tag'
                                                              : title,
                                                          maxLength: 36,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13.5,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w700
                                                              : FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),

                                          // 3. "+ Load File" option
                                          const SizedBox(height: 8),
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            onTap: onLoadSubtitleFile,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 7,
                                                horizontal: 2,
                                              ),
                                              child: Row(
                                                children: const [
                                                  Icon(
                                                    Symbols.upload_file_rounded,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '+ Load File',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
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
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
