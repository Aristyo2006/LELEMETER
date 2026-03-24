import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'exposure_state.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ExposureState(),
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
            primaryColor: state.primaryColor,
            colorScheme: ColorScheme.light(
              primary: state.primaryColor,
              secondary: const Color(0xFF03DAC6),
              surface: Colors.white,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0E0E0E), // OLED Black
            primaryColor: state.primaryColor,
            colorScheme: ColorScheme.dark(
              primary: state.primaryColor,
              secondary: const Color(0xFF9D9E9E), // Grey from design
              tertiary: const Color(0xFF8EFF71), // Neon Green from design
              surface: const Color(0xFF0E0E0E),
              surfaceContainer: const Color(0xFF131313),
              onSurface: const Color(0xFFE7E5E5),
              onSurfaceVariant: const Color(0xFFACABAA),
            ),
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme.copyWith(
                    displayLarge: GoogleFonts.spaceGrotesk(),
                    displayMedium: GoogleFonts.spaceGrotesk(),
                    displaySmall: GoogleFonts.spaceGrotesk(),
                    headlineLarge: GoogleFonts.spaceGrotesk(),
                    headlineMedium: GoogleFonts.spaceGrotesk(),
                    headlineSmall: GoogleFonts.spaceGrotesk(),
                    titleLarge: GoogleFonts.spaceGrotesk(),
                    titleMedium: GoogleFonts.spaceGrotesk(),
                    titleSmall: GoogleFonts.spaceGrotesk(),
                  ),
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
