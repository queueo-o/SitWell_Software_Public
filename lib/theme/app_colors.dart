import 'package:flutter/material.dart';

class AppColors {
  final Color bg;
  final Color surface;
  final Color surfaceDeep;
  final Color accent;
  final Color green;
  final Color amber;
  final Color pink;
  final Color textPri;
  final Color textMuted;
  final Color border;

  const AppColors._({
    required this.bg,
    required this.surface,
    required this.surfaceDeep,
    required this.accent,
    required this.green,
    required this.amber,
    required this.pink,
    required this.textPri,
    required this.textMuted,
    required this.border,
  });

  static const dark = AppColors._(
    bg:          Color(0xFF060D1F),
    surface:     Color(0xFF0D1A2E),
    surfaceDeep: Color(0xFF0D2535),
    accent:      Color(0xFF00E5FF),
    green:       Color(0xFF00E096),
    amber:       Color(0xFFFFB020),
    pink:        Color(0xFFFF4D8D),
    textPri:     Colors.white,
    textMuted:   Color(0xFF6B7A96),
    border:      Color(0xFF1A2640),
  );

  static const light = AppColors._(
    bg:          Color(0xFFF0F5FF),
    surface:     Colors.white,
    surfaceDeep: Color(0xFFEBF2FF),
    accent:      Color(0xFF0099AA),
    green:       Color(0xFF00875A),
    amber:       Color(0xFFB86800),
    pink:        Color(0xFFB5004F),
    textPri:     Color(0xFF0A1628),
    textMuted:   Color(0xFF5B7090),
    border:      Color(0xFFCDD8F0),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
