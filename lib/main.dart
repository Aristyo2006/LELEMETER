import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'exposure_state.dart';
import 'splash_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (clightmeteontext) => ExposureState(),
      child: const LightMeterApp(),
    ),
  );
}

class LightMeterApp extends StatelessWidget {
  const LightMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExposureState>(
      builder: (context, state, child) {
        return MaterialApp(
          title: 'Lelemeter',
          themeMode: state.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            primaryColor: const Color(0xFFFFB300), // Amber highlight
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFB300),
              secondary: Color(0xFF03DAC6),
              surface: Colors.white,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
            primaryColor: const Color(0xFFFFB300), // Amber highlight
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFB300),
              secondary: Color(0xFF03DAC6),
              surface: Color(0xFF1E1E1E),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
