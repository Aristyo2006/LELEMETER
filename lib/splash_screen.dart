import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'exposure_state.dart';
import 'light_meter_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Start progress animation (minimum 2s duration for brand presence)
    final startTime = DateTime.now();
    _controller.forward();

    // 2. Pre-load check (already bundled, but we can wait for engine readiness if needed)
    // No longer needs GoogleFonts.pendingFonts() as they are in pubspec.yaml
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Wait for ExposureState to be fully ready (SharedPreferences, etc.)
    final state = Provider.of<ExposureState>(context, listen: false);
    while (!state.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 4. Ensure we show the splash for at least 2 seconds for smooth transition
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsed);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LightMeterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Logo (smaller, top aligned)
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'LELEMETER',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),

                  // SYSTEM STATUS Header
                  Text(
                    'SYSTEM STATUS',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: const Color(0xFFACABAA),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Row: LED + Label + Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Glowing Green Dot
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8EFF71),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8EFF71).withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'CALIBRATING SENSORS',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: const Color(0xFFD6FF71),
                            ),
                          ),
                        ],
                      ),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Text(
                            '${(_controller.value * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF09819),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Striped Progress Bar
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        height: 28,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CustomPaint(
                          painter: StripedProgressPainter(
                            progress: _controller.value,
                            stripeColor: const Color(0xFFF09819),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Version Milestone Footer
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.4,
                child: Column(
                  children: [
                    Text(
                      'BUILD v2.0.0',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MILESTONE 1 // HARDWARE CORE',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 8,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StripedProgressPainter extends CustomPainter {
  final double progress;
  final Color stripeColor;

  StripedProgressPainter({required this.progress, required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF131313);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final double width = size.width * progress;
    final double stripeWidth = 12;
    final double gap = 8;
    final double totalWidth = stripeWidth + gap;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, size.height));

    // Base fill (softer amber)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, size.height),
      Paint()..color = stripeColor.withValues(alpha: 0.8),
    );

    // Draw Diagonal Stripes
    final stripePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    for (double i = -size.height; i < size.width + size.height; i += totalWidth) {
      final path = Path();
      path.moveTo(i, 0);
      path.lineTo(i + stripeWidth, 0);
      path.lineTo(i + stripeWidth - size.height, size.height);
      path.lineTo(i - size.height, size.height);
      path.close();
      canvas.drawPath(path, stripePaint);
    }

    // Right Edge Glow/Highlight
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(width, 0), Offset(width, size.height), edgePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StripedProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
