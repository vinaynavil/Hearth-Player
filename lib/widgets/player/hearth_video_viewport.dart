import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'player_controls.dart';

/// Full-screen video player viewport with controls, audio/subtitle selector, and gestures.
class HearthVideoViewport extends StatelessWidget {
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

  const HearthVideoViewport({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PlayerControls(
        player: player,
        videoController: videoController,
        videoPath: videoPath,
        positionNotifier: positionNotifier,
        duration: duration,
        bufferNotifier: bufferNotifier,
        isPlaying: isPlaying,
        volume: volume,
        isMuted: isMuted,
        playbackSpeed: playbackSpeed,
        isFullscreen: isFullscreen,
        tracks: tracks,
        activeTrack: activeTrack,
        resumedFromSeconds: resumedFromSeconds,
        subtitleDragOffset: subtitleDragOffset,
        onSubtitleDragOffsetChanged: onSubtitleDragOffsetChanged,
        onPlayPause: onPlayPause,
        onScrubberChanged: onScrubberChanged,
        onScrubberChangeEnd: onScrubberChangeEnd,
        onStepBackward: onStepBackward,
        onStepForward: onStepForward,
        onToggleMute: onToggleMute,
        onPlaybackSpeedSelected: onPlaybackSpeedSelected,
        onToggleFullscreen: onToggleFullscreen,
        onBackToLibrary: onBackToLibrary,
        onStartOver: onStartOver,
        onAudioTrackSelected: onAudioTrackSelected,
        onSubtitleTrackSelected: onSubtitleTrackSelected,
        onLoadSubtitleFile: onLoadSubtitleFile,
      ),
    );
  }
}
