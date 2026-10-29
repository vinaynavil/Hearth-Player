import 'package:flutter/material.dart';

// =============================================================================
// HEARTH FLUENT THEME TOKENS
// =============================================================================
class HearthTheme {
  static const String fontFamily = 'Segoe UI Variable';
  static const List<String> fontFallback = ['Segoe UI', 'Geist', 'sans-serif'];

  // Motion Curves (Emil Design Eng standard)
  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0);
  static const Curve easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  // Motion Durations
  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationMedium = Duration(milliseconds: 160);
  static const Duration durationOverlay = Duration(milliseconds: 190);

  // Deep optical navy-obsidian frosted glass base over Windows MicaAlt
  static const Color windowTintTop = Color(0xB30A0D14); // ~70% deep navy-obsidian glass veil
  static const Color windowTintBottom = Color(0xD90D1017); // ~85% frosted sidebar/drawer glass tone
  static const Color sidebarSurface = Colors.transparent;
  static const Color topBarSurface = Color(0x400A0D14); // Subtle translucent top bar glaze

  // Translucent frosted content canvas (lets the unified glass backdrop breathe through)
  static const Color contentAreaSurface = Color(0x990D1017); // ~60% deep navy-obsidian glass layer
  static const Color contentAreaBorder = Color(0x14FFFFFF);  // Crisp ~8% white optical glass edge stroke

  // Translucent optical glass card surfaces inside the content layer
  static const Color cardSurface = Color(0x0DFFFFFF); // ~5% white glass card fill
  static const Color cardSurfaceHover = Color(0x18FFFFFF); // ~9.5% white luminous hover fill
  static const Color cardOverlayFill = Color(0x0DFFFFFF);

  // Specular glass borders
  static const Color subtleBorder = Color(0x12FFFFFF); // ~7% white subtle glass rim
  static const Color hoverBorder = Color(0x24FFFFFF);  // ~14% white hover rim
  static const Color activeBorder = Color(0x2EFFFFFF); // ~18% white active rim

  // Hearth signature periwinkle-royal blue accent (matches brand title & icon)
  static const Color accent = Color(0xFF5874EE);
  static const Color accentHover = Color(0xFF6E87F5);
  static const Color accentPressed = Color(0xFF4560D9);
  static const Color accentSubtleFill = Color(0x1AFFFFFF); // Luminous selected nav pill fill

  // Semantic Danger / Alert Tokens (to replace hardcoded hex in player_controls)
  static const Color dangerSurface = Color(0x38EF4444);
  static const Color dangerBorder = Color(0x73EF4444);
  static const Color dangerText = Color(0xFFF87171);
  static const Color pillSurface = Color(0xE0141821);

  // Control fills (optical glass buttons & inputs)
  static const Color buttonRest = Color(0x14FFFFFF);
  static const Color buttonHover = Color(0x22FFFFFF);
  static const Color buttonPressed = Color(0x0CFFFFFF);

  // Typography colors (neutral WinUI 3 dark mode)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC5C5C5);
  static const Color textMuted = Color(0xFF8A8A8A);

  // Dimensions from task_page.py
  static const double cardRadius = 10.0;
  static const double buttonRadius = 7.0;

  // Shadow from TaskCommandBarView in task_page.py: blur 35, offset (0, 8), alpha 80
  static const List<BoxShadow> fluentShadow = [
    BoxShadow(
      color: Color(0x50000000),
      blurRadius: 35,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x38000000),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];

  // Tabular Figures Helper
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  // Break-UI String Helpers
  static String middleTruncate(String text, {int maxLength = 48}) {
    if (text.length <= maxLength || maxLength <= 3) return text;
    final int head = (maxLength - 1) ~/ 2;
    final int tail = maxLength - 1 - head;
    return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
  }

  static String pluralize(int count, String singular, [String? plural]) {
    return '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
  }
}
