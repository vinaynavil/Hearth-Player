import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/hearth_theme.dart';

/// Flyout settings panel for switching playback speed.
class SpeedPanel extends StatelessWidget {
  final bool isVisible;
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;
  final VoidCallback? onPanelHoverEnter;
  final VoidCallback? onPanelHoverExit;
  final ui.Image? snapshotImage;
  final GlobalKey? panelKey;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  const SpeedPanel({
    super.key,
    required this.isVisible,
    required this.currentSpeed,
    required this.onSpeedSelected,
    this.onPanelHoverEnter,
    this.onPanelHoverExit,
    this.snapshotImage,
    this.panelKey,
  });

  @override
  Widget build(BuildContext context) {
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
                alignment: Alignment.bottomCenter,
                duration: isVisible ? HearthTheme.durationOverlay : HearthTheme.durationFast,
                curve: HearthTheme.easeOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                        width: 110,
                        decoration: BoxDecoration(
                          color: Colors.black
                              .withValues(alpha: snapshotImage != null ? 0.82 : 0.86),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HearthTheme.subtleBorder,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _speeds.map((speed) {
                          final bool isSelected = currentSpeed == speed;
                          return InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => onSpeedSelected(speed),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${speed}x',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      fontFeatures: HearthTheme.tabularFigures,
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Symbols.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
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
