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
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: state.isPureBlack ? Colors.black : const Color(0xFF0F0F0F),
            primaryColor: state.primaryColor,
            colorScheme: ColorScheme.dark(
              primary: state.primaryColor,
              secondary: const Color(0xFF03DAC6),
              surface: state.isPureBlack ? Colors.black : const Color(0xFF1E1E1E),
              surfaceContainer: state.isPureBlack ? const Color(0xFF121212) : const Color(0xFF242424),
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
