import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logbook_screen.dart';
import 'logbook_store.dart';

/// Entry point for the Logbook from the bottom-nav LOG button.
///
/// Every open plays a 3D page-flip cover animation.
/// On exit (system back) the cover closes back with a reverse flip.
/// The [LogbookScreen] is pre-warmed in [Offstage] during the cover phase
/// so images decode & raster cache warms up — zero pop-in on reveal.
class LogbookCoverScreen extends StatefulWidget {
  const LogbookCoverScreen({super.key});

  @override
  State<LogbookCoverScreen> createState() => _LogbookCoverScreenState();
}

class _LogbookCoverScreenState extends State<LogbookCoverScreen>
    with TickerProviderStateMixin {
  // Phases:
  //   null  = still loading store
  //   true  = showing cover (flip animation active)
  //   false = cover done, showing the actual list
  bool? _showCover;

  // 3D page-flip animation.
  late final AnimationController _flip;
  late final Animation<double> _coverRotation;

  // Whether we're currently closing (reverse animation playing).
  bool _closing = false;

  // Perspective depth.
  static const double _perspective = 0.0012;

  @override
  void initState() {
    super.initState();

    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 850),
    );

    // Cover rotates 0 → +π around the left edge (book spine).
    // Two-phase for a natural page-turn feel:
    //   0 → π/2  : slow ease-in, cover lifting from table
    //   π/2 → π  : fast ease-out, cover snapping behind
    _coverRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: math.pi * 0.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: math.pi * 0.5, end: math.pi)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
    ]).animate(_flip);

    _flip.addStatusListener(_onFlipStatus);

    _init();
  }

  void _onFlipStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_closing) {
      // Opening finished → swap from cover to the real list.
      setState(() => _showCover = false);
    } else if (status == AnimationStatus.dismissed && _closing) {
      // Closing finished → pop back to the main screen.
      Navigator.of(context).pop();
    }
  }

  Future<void> _init() async {
    await LogbookStore.instance.ensureInitialized();
    if (!mounted) return;
    setState(() => _showCover = true);

    // Dwell on the cover briefly so the "book" registers, then open.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _flip.forward();
  }

  Future<void> _handleBack() async {
    if (_closing) return;

    if (_showCover == null) {
      // Still loading → just pop.
      Navigator.of(context).pop();
      return;
    }

    // Cover hasn't finished opening yet → snap and pop.
    if (_flip.isAnimating) {
      Navigator.of(context).pop();
      return;
    }

    if (_showCover == true) {
      // Still showing cover (shouldn't normally happen since _flip isCompleted
      // triggers swap to false, but just in case).
      Navigator.of(context).pop();
      return;
    }

    // List is visible → play the cover-close animation.
    setState(() {
      _showCover = true; // bring back the cover
      _closing = true;
    });
    await _flip.reverse();
  }

  @override
  void dispose() {
    _flip.removeStatusListener(_onFlipStatus);
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Still loading store → flat background + pre-warm list in Offstage.
    if (_showCover == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1614),
        body: Offstage(child: LogbookScreen()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1614),
        body: Stack(
          children: [
            // The real list — ALWAYS painted (even while cover is showing)
            // so its raster cache warms up. Opaque paper background means
            // it's visually hidden behind the cover anyway.
            const LogbookScreen(),

            // The cover — present while _showCover == true.
            // Rotates the full 0 → π arc without disappearing mid-flip,
            // so there's never a black gap. Once flip completes we swap
            // _showCover=false via setState and the cover unmounts.
            if (_showCover == true)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _coverRotation,
                    builder: (context, child) {
                      final angle = _coverRotation.value;

                      return Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, _perspective)
                          ..rotateY(angle),
                        child: child!,
                      );
                    },
                    child: const RepaintBoundary(child: _Cover()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cover artwork — all const StatelessWidgets / shouldRepaint:false painters.
// Drawn exactly once, cached by the RasterCache inside the RepaintBoundary.
// ─────────────────────────────────────────────────────────────────────────────

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Leather base + film grain (painted once, never repaints)
          const CustomPaint(painter: _LeatherPainter()),
          // Dashed stitched perimeter
          const CustomPaint(painter: _StitchedBorderPainter()),
          // Right-side spine strap + brass clasp
          const Align(alignment: Alignment.centerRight, child: _ClosureStrap()),
          // Centre title — debossed letterpress look
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LELEMETER\nLOGBOOK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      height: 1.35,
                      color: Color(0xFF3E3428),
                      shadows: [
                        Shadow(color: Color(0x12FFFFFF), offset: Offset(1, 1)),
                        Shadow(
                          color: Color(0xE6000000),
                          offset: Offset(-1, -1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(width: 72, height: 1, color: const Color(0x12FFFFFF)),
                ],
              ),
            ),
          ),
          // Tipped-in paper label (bottom-left)
          const Positioned(
            bottom: 120,
            left: 40,
            child: _TippedInLabel(),
          ),
          // Vignette — painted once
          const Positioned.fill(child: IgnorePointer(child: _Vignette())),
        ],
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.15,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
        ),
      ),
    );
  }
}

// ── Painters (shouldRepaint = false → drawn once, raster-cached) ─────────────

class _LeatherPainter extends CustomPainter {
  const _LeatherPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2520), Color(0xFF1E1A16), Color(0xFF161210)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.035), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    final grainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.016)
      ..style = PaintingStyle.fill;
    final rng = _SeededRng(42);
    for (int i = 0; i < 2500; i++) {
      canvas.drawCircle(
        Offset(rng.next() * size.width, rng.next() * size.height),
        0.45,
        grainPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _StitchedBorderPainter extends CustomPainter {
  const _StitchedBorderPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 18.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
          const Radius.circular(6),
        ),
      );

    const dash = 5.0, gap = 5.0;
    final dashed = Path();
    for (final m in path.computeMetrics()) {
      double d = 0;
      bool draw = true;
      while (d < m.length) {
        final len = draw ? dash : gap;
        if (draw) dashed.addPath(m.extractPath(d, d + len), Offset.zero);
        d += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SeededRng {
  int _s;
  _SeededRng(this._s);
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_s & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}

// ── Closure strap (right spine) — precomputed, no MediaQuery rebuild ─────────

class _ClosureStrap extends StatelessWidget {
  const _ClosureStrap();
  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.09,
      alignment: Alignment.centerRight,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            alignment: Alignment.centerRight,
            children: [
              Container(
                width: w * 0.78,
                height: h * 0.85,
                decoration: BoxDecoration(
                  color: const Color(0xFF141210),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(-2, 0),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: h * 0.5 - 17,
                child: Container(
                  width: w * 0.68,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD4AF37), Color(0xFF8A6D3B)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                    border: Border.all(color: const Color(0x806B5020)),
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0x805A4010), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Tipped-in paper label ────────────────────────────────────────────────────

class _TippedInLabel extends StatelessWidget {
  const _TippedInLabel();
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.018,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFAF4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(2, 3),
                ),
              ],
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PHOTO LOGBOOK',
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A2520),
                  ),
                ),
                Text(
                  'VOLUME IV',
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 16,
                    color: Color(0x8C2A2520),
                  ),
                ),
              ],
            ),
          ),
          // Washi tape strip
          Positioned(
            top: -10,
            left: 22,
            child: Transform.rotate(
              angle: 0.04,
              child: Container(
                width: 54,
                height: 15,
                color: const Color(0x61D2C8B4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
