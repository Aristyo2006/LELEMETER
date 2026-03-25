import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
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
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return Consumer<ExposureState>(
          builder: (context, state, child) {
            final brightness = state.themeMode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context)
                : (state.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
            
            final dynamicAccent = brightness == Brightness.dark 
                ? darkDynamic?.primary 
                : lightDynamic?.primary;
            
            if (dynamicAccent != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                state.setDynamicAccent(dynamicAccent);
              });
            }

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
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(fontFamily: 'Inter'),
                  bodyMedium: TextStyle(fontFamily: 'Inter'),
                  bodySmall: TextStyle(fontFamily: 'Inter'),
                  displayLarge: TextStyle(fontFamily: 'Inter'),
                  displayMedium: TextStyle(fontFamily: 'Inter'),
                  displaySmall: TextStyle(fontFamily: 'Inter'),
                  headlineLarge: TextStyle(fontFamily: 'Inter'),
                  headlineMedium: TextStyle(fontFamily: 'Inter'),
                  headlineSmall: TextStyle(fontFamily: 'Inter'),
                  labelLarge: TextStyle(fontFamily: 'Inter'),
                  labelMedium: TextStyle(fontFamily: 'Inter'),
                  labelSmall: TextStyle(fontFamily: 'Inter'),
                  titleLarge: TextStyle(fontFamily: 'Inter'),
                  titleMedium: TextStyle(fontFamily: 'Inter'),
                  titleSmall: TextStyle(fontFamily: 'Inter'),
                ),
                useMaterial3: true,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: state.isPureBlack 
                    ? Colors.black 
                    : const Color(0xFF0E0E0E),
                primaryColor: state.primaryColor,
                colorScheme: ColorScheme.dark(
                  primary: state.primaryColor,
                  secondary: const Color(0xFF9D9E9E),
                  tertiary: const Color(0xFF8EFF71),
                  surface: state.isPureBlack ? Colors.black : const Color(0xFF0E0E0E),
                  surfaceContainer: const Color(0xFF131313),
                  onSurface: const Color(0xFFE7E5E5),
                  onSurfaceVariant: const Color(0xFFACABAA),
                ),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(fontFamily: 'Inter'),
                  bodyMedium: TextStyle(fontFamily: 'Inter'),
                  bodySmall: TextStyle(fontFamily: 'Inter'),
                  displayLarge: TextStyle(fontFamily: 'SpaceGrotesk'),
                  displayMedium: TextStyle(fontFamily: 'SpaceGrotesk'),
                  displaySmall: TextStyle(fontFamily: 'SpaceGrotesk'),
                  headlineLarge: TextStyle(fontFamily: 'SpaceGrotesk'),
                  headlineMedium: TextStyle(fontFamily: 'SpaceGrotesk'),
                  headlineSmall: TextStyle(fontFamily: 'SpaceGrotesk'),
                  labelLarge: TextStyle(fontFamily: 'Inter'),
                  labelMedium: TextStyle(fontFamily: 'Inter'),
                  labelSmall: TextStyle(fontFamily: 'Inter'),
                  titleLarge: TextStyle(fontFamily: 'SpaceGrotesk'),
                  titleMedium: TextStyle(fontFamily: 'SpaceGrotesk'),
                  titleSmall: TextStyle(fontFamily: 'SpaceGrotesk'),
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
      },
    );
  }
}
