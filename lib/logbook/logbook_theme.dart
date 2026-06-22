import 'package:flutter/material.dart';

import '../ui_helpers.dart';

/// Shared "old book / aged paper" styling for the Logbook screens.
/// Keeps performance tight: paper color is a flat tint (cheap) and the grain is
/// a single opacity-08 `DecorationImage` over the whole screen (re-uses the
/// existing `skeuomorphicNoise` asset, already pre-cached at app start).
class LogbookTheme {
  // Paper tones — warm cream in light mode, warm near-black in dark mode.
  static const Color paperLight = Color(0xFFF4ECD8);
  static const Color paperDark = Color(0xFF1B1814);
  static const Color inkLight = Color(0xFF3A322A);
  static const Color inkDark = Color(0xFFE8DFC9);
  static const Color fadedLight = Color(0xFF8A7E68);
  static const Color fadedDark = Color(0xFFA89B82);
  static const Color accent = Color(0xFF8EFF71);

  static Color paper(bool isDark) => isDark ? paperDark : paperLight;
  static Color ink(bool isDark) => isDark ? inkDark : inkLight;
  static Color faded(bool isDark) => isDark ? fadedDark : fadedLight;

  /// Build a stack: paper tint + subtle grain overlay + content.
  static Widget paperBackground({required bool isDark, required Widget child}) {
    return Stack(
      children: [
        // Flat base color — cheapest possible fill, repaints never.
        Positioned.fill(child: ColoredBox(color: paper(isDark))),
        // Grain overlay: one opaque image, very low opacity, cached by engine.
        Positioned.fill(
          child: IgnorePointer(
            child: Image(
              image: skeuomorphicNoise.image,
              fit: BoxFit.cover,
              opacity: AlwaysStoppedAnimation(isDark ? 0.05 : 0.08),
              gaplessPlayback: true,
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Handwritten display text helper.
TextStyle caveat({
  double size = 20,
  FontWeight weight = FontWeight.normal,
  Color? color,
  double height = 1.15,
}) =>
    TextStyle(
      fontFamily: 'Caveat',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

/// Monospace-ish setting line (uses the existing VT323 terminal font for a
/// "stamped/printed" feel next to the handwritten notes).
TextStyle stampStyle({Color? color, double size = 14}) => TextStyle(
      fontFamily: 'VT323',
      fontSize: size,
      color: color,
      letterSpacing: 0.5,
      height: 1.1,
    );

/// The back-button + centered title header used by all three logbook screens,
/// mirroring [SettingsScreen._buildHeader] but themed for paper.
Widget buildBookHeader(
  BuildContext context,
  String title, {
  String? subtitle,
  List<Widget>? actions,
  VoidCallback? onBack,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: LogbookTheme.paper(isDark),
      border: Border(
        bottom: BorderSide(
          color: LogbookTheme.faded(isDark).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back,
              color: LogbookTheme.ink(isDark),
              size: 22,
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                style: caveat(
                  size: 30,
                  weight: FontWeight.bold,
                  color: LogbookTheme.ink(isDark),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: stampStyle(
                    color: LogbookTheme.faded(isDark),
                    size: 12,
                  ),
                ),
            ],
          ),
        ),
        if (actions != null)
          Row(mainAxisSize: MainAxisSize.min, children: actions)
        else
          const SizedBox(width: 44),
      ],
    ),
  );
}

class LinedPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;
  final double offsetTop;

  const LinedPaperPainter({
    required this.lineColor,
    required this.lineHeight,
    this.offsetTop = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;
    double y = offsetTop;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant LinedPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.offsetTop != offsetTop;
  }
}
