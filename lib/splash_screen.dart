import 'package:flutter/material.dart';
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
    )..forward().then((_) {
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
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sleek black for splash screen
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset(
              'assets/logo.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            // LELEMETER Text Logo
            Text(
              'LELEMETER',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).primaryColor,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            // Loading Bar
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _controller.value,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      minHeight: 4,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'CALIBRATING SENSORS...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
