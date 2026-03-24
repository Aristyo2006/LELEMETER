import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:battery_plus/battery_plus.dart';
import 'exposure_state.dart';
import 'exposure_calculator.dart';
import 'film_database_screen.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';

class LightMeterScreen extends StatelessWidget {
  const LightMeterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExposureState>(
      builder: (context, state, child) {
        final isDark = state.themeMode == ThemeMode.dark;
        return Scaffold(
          backgroundColor: isDark
              ? (state.isPureBlack ? Colors.black : const Color(0xFF1A1B1E))
              : const Color(0xFFF5F5F5),
          body: Builder(
            builder: (context) {
              // Show sensor support alert if needed
              if (!state.hasSensor && !state.hasShownSensorAlert) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showSensorSupportAlert(context, state);
                });
              }

              return Stack(
                children: [
                  // Background pattern
                  Positioned.fill(
                    child: CustomPaint(painter: _BackgroundPatternPainter()),
                  ),
                  Column(
                    children: [
                      _buildProHeader(context, state),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              _buildGlassReadout(context, state),
                              const SizedBox(height: 16),
                              _buildQuickControls(context, state),
                              const SizedBox(height: 24),
                              _buildMechanicalInterface(context, state),
                              const SizedBox(
                                height: 100,
                              ), // Space for bottom nav
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildProBottomNav(context, state),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProHeader(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.dark;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131313) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'LELEMETER',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: state.primaryColor,
                    fontSize: 16,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'SYNCED',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8EFF71),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.sensors, size: 18, color: state.primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryIcon(ExposureState state, Color lcdInk) {
    final isCharging = state.currentBatteryState == BatteryState.charging ||
        state.currentBatteryState == BatteryState.full;
    final level = state.batteryLevel;

    IconData icon;
    Color color;

    if (isCharging) {
      icon = Icons.battery_charging_full;
      color = const Color(0xFF8EFF71);
    } else if (level < 20) {
      icon = Icons.battery_alert;
      color = const Color(0xFFEE7D77);
    } else if (level < 40) {
      icon = Icons.battery_2_bar;
      color = lcdInk;
    } else if (level < 60) {
      icon = Icons.battery_4_bar;
      color = lcdInk;
    } else if (level < 80) {
      icon = Icons.battery_5_bar;
      color = lcdInk;
    } else {
      icon = Icons.battery_full;
      color = lcdInk;
    }

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildBatteryStatusChip(ExposureState state, Color lcdInk) {
    final isCharging = state.currentBatteryState == BatteryState.charging ||
        state.currentBatteryState == BatteryState.full;
    final isLow = state.batteryLevel > 0 && state.batteryLevel < 20;

    final String label;
    final Color color;

    if (isCharging) {
      label = '⚡CHARG';
      color = const Color(0xFF8EFF71); // green
    } else if (isLow) {
      label = '!LOW';
      color = const Color(0xFFEE7D77); // red
    } else {
      label = state.batteryLevel <= 0 ? '--%' : '${state.batteryLevel}%';
      color = lcdInk;
    }

    return Text(
      label,
      style: GoogleFonts.vt323(
        fontSize: 14,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGlassReadout(BuildContext context, ExposureState state) {
    const lcdBg = Color(0xFF97A393); // Classic LCD backdrop
    const lcdInk = Color(0xFF1A1F18); // LCD segment color

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lcdBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Top Indicator Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ISO :  ${state.iso}',
                  style: GoogleFonts.vt323(fontSize: 14, color: lcdInk),
                ),
                Row(
                  children: [
                    _buildBatteryIcon(state, lcdInk),
                    const SizedBox(width: 4),
                    _buildBatteryStatusChip(state, lcdInk),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: lcdInk.withValues(alpha: 0.2)),
            const SizedBox(height: 16),

            // AT-A-GLANCE T/F ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Shutter (T)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'T',
                      style: GoogleFonts.vt323(fontSize: 16, color: lcdInk),
                    ),
                    Text(
                      ExposureCalculator.formatShutterSpeed(state.shutterSpeed),
                      style: GoogleFonts.vt323(
                        fontSize: 56,
                        height: 0.9,
                        color: lcdInk,
                        letterSpacing: -2,
                      ),
                    ),
                  ],
                ),
                // Indicator
                if (state.target == CalculationTarget.shutter)
                  const Icon(Icons.arrow_left, size: 16, color: lcdInk)
                else if (state.target == CalculationTarget.aperture)
                  const Icon(Icons.arrow_right, size: 16, color: lcdInk)
                else
                  const SizedBox(width: 16),
                // Aperture (F)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'F',
                      style: GoogleFonts.vt323(fontSize: 16, color: lcdInk),
                    ),
                    Text(
                      ExposureCalculator.formatAperture(
                        state.aperture,
                      ).replaceAll('f/', ''),
                      style: GoogleFonts.vt323(
                        fontSize: 56,
                        height: 0.9,
                        color: lcdInk,
                        letterSpacing: -2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats & EV Row (Balanced Flex Layout)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildLcdStat(
                    'EV',
                    state.effectiveLux <= 0
                        ? '--.-'
                        : state.ev.toStringAsFixed(1),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: lcdInk.withValues(alpha: 0.2),
                ),
                Expanded(
                  flex: 2,
                  child: _buildLcdStat(
                    'LUX',
                    state.effectiveLux.toInt().toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: lcdInk.withValues(alpha: 0.2),
                ),
                Expanded(
                  flex: 2,
                  child: _buildLcdStat('ND', state.ndFilter.name),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: lcdInk.withValues(alpha: 0.2),
                ),
                Expanded(
                  flex: 4,
                  child: _buildLcdStat(
                    'FILM',
                    state.selectedFilm?.name ?? 'NONE',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildExposureBar(state),
          ],
        ),
      ),
    );
  }

  Widget _buildLcdStat(String label, String value) {
    const lcdInk = Color(0xFF1A1F18);
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.vt323(fontSize: 10, color: lcdInk),
        ),
        Text(
          value.toUpperCase(),
          style: GoogleFonts.vt323(fontSize: 22, color: lcdInk),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildExposureBar(ExposureState state) {
    // Delta range from -3 to +3 stops for the bar visualization
    final double delta = state.exposureCompensation.clamp(-3.0, 3.0);
    final double progress = (delta + 3.0) / 6.0;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Container(
              height: 4,
              width: width,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F18).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Center marker
                  Center(
                    child: Container(
                      width: 2,
                      height: 4,
                      color: const Color(0xFF1A1F18).withValues(alpha: 0.3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.only(
                      left: progress > 0.5 ? width / 2 : width * progress,
                    ),
                    width: (progress - 0.5).abs() * width,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8EFF71),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8EFF71).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '-3',
              style: GoogleFonts.vt323(
                fontSize: 10,
                color: const Color(0xFF1A1F18),
              ),
            ),
            Text(
              '0',
              style: GoogleFonts.vt323(
                fontSize: 10,
                color: const Color(0xFF1A1F18),
              ),
            ),
            Text(
              '+3',
              style: GoogleFonts.vt323(
                fontSize: 10,
                color: const Color(0xFF1A1F18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickControls(BuildContext context, ExposureState state) {
    return Row(
      children: [
        Expanded(
          child: _build3DQuickButton(
            label: state.isLocked ? 'LOCKED' : 'LOCK SENSOR',
            icon: state.isLocked ? Icons.lock : Icons.lock_open,
            isActive: state.isLocked,
            color: state.isLocked
                ? const Color(0xFFFBBC00)
                : const Color(0xFFE7E5E5),
            onTap: () => state.toggleLock(),
          ),
        ),
      ],
    );
  }

  Widget _build3DQuickButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]
                : [const Color(0xFF2A2A2A), const Color(0xFF131313)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? color : const Color(0xFF767575),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: isActive ? color : const Color(0xFF767575),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.dark;
    final modes = [
      {'label': 'P', 'full': 'PROGRAM', 'target': CalculationTarget.shutter},
      {'label': 'A', 'full': 'APERTURE', 'target': CalculationTarget.aperture},
      {'label': 'S', 'full': 'SHUTTER', 'target': CalculationTarget.shutter},
    ];

    return Row(
      children: modes.map((m) {
        // Since we don't have distinct PASM enums yet, we'll map them loosely to the current targets
        bool isActive = false;
        if (m['label'] == 'A' && state.target == CalculationTarget.aperture)
          isActive = true;
        if (m['label'] == 'S' && state.target == CalculationTarget.shutter)
          isActive = true;
        if (m['label'] == 'P' && !isActive)
          isActive = true; // Temporary P fallback

        return Expanded(
          child: GestureDetector(
            onTap: () {
              state.setTarget(m['target'] as CalculationTarget);
              HapticFeedback.lightImpact();
            },
            child: Container(
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isActive
                      ? [
                          state.primaryColor,
                          state.primaryColor.withValues(alpha: 0.6),
                        ]
                      : (isDark
                            ? [const Color(0xFF444444), const Color(0xFF1E1E1E)]
                            : [
                                const Color(0xFFFFFFFF),
                                const Color(0xFFE5E5E5),
                              ]),
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isActive
                      ? state.primaryColor.withValues(alpha: 0.8)
                      : (isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFD4D4D4)),
                  width: 1,
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          offset: const Offset(1.5, 2.5),
                          blurRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.03),
                          offset: const Offset(-1, -1),
                          blurRadius: 2,
                        ),
                        BoxShadow(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          offset: const Offset(0, 1),
                          blurStyle: BlurStyle.inner,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: const Offset(1, 2),
                          blurRadius: 3,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-1, -1),
                          blurRadius: 2,
                        ),
                        BoxShadow(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.9),
                          offset: const Offset(0, 1),
                          blurStyle: BlurStyle.inner,
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    m['label'] as String,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.black : Colors.white,
                    ),
                  ),
                  Text(
                    m['full'] as String,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? Colors.black.withValues(alpha: 0.5)
                          : const Color(0xFF767575),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMechanicalInterface(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.dark;
    return Column(
      children: [
        _buildModeSelector(context, state),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _build3DControlBlock(
                label: 'SHUTTER',
                value: ExposureCalculator.formatShutterSpeed(
                  state.shutterSpeed,
                ),
                color: state.target == CalculationTarget.shutter
                    ? state.primaryColor
                    : (isDark ? Colors.white : Colors.black),
                isDark: isDark,
                onDecrement: () => state.setShutterSpeed(
                  state.shutterValues[math.max(
                    0,
                    state.shutterValues.indexOf(state.shutterSpeed) - 1,
                  )],
                ),
                onIncrement: () => state.setShutterSpeed(
                  state.shutterValues[math.min(
                    state.shutterValues.length - 1,
                    state.shutterValues.indexOf(state.shutterSpeed) + 1,
                  )],
                ),
                onTap: () => state.setTarget(CalculationTarget.shutter),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _build3DControlBlock(
                label: 'APERTURE',
                value: ExposureCalculator.formatAperture(state.aperture),
                color: state.target == CalculationTarget.aperture
                    ? state.primaryColor
                    : (isDark ? Colors.white : Colors.black),
                isDark: isDark,
                onDecrement: () => state.setAperture(
                  state.apertureValues[math.max(
                    0,
                    state.apertureValues.indexOf(state.aperture) - 1,
                  )],
                ),
                onIncrement: () => state.setAperture(
                  state.apertureValues[math.min(
                    state.apertureValues.length - 1,
                    state.apertureValues.indexOf(state.aperture) + 1,
                  )],
                ),
                onTap: () => state.setTarget(CalculationTarget.aperture),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _build3DControlBlock(
                label: 'ISO SPEED',
                value: state.iso.toString(),
                color: state.selectedFilm != null
                    ? const Color(0xFF42A5F5)
                    : (state.target == CalculationTarget.iso
                          ? state.primaryColor
                          : (isDark ? Colors.white : Colors.black)),
                isDark: isDark,
                onDecrement: state.selectedFilm != null
                    ? () {}
                    : () => state.setIso(
                        state.isoValues[math.max(
                          0,
                          state.isoValues.indexOf(state.iso) - 1,
                        )],
                      ),
                onIncrement: state.selectedFilm != null
                    ? () {}
                    : () => state.setIso(
                        state.isoValues[math.min(
                          state.isoValues.length - 1,
                          state.isoValues.indexOf(state.iso) + 1,
                        )],
                      ),
                onTap: state.selectedFilm != null
                    ? () {}
                    : () => state.setTarget(CalculationTarget.iso),
                isLocked: state.selectedFilm != null,
                caption: state.selectedFilm != null ? 'FILM' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _build3DControlBlock(
                label: 'EXP. COMP',
                value:
                    '${state.exposureCompensation >= 0 ? '+' : ''}${state.exposureCompensation.toStringAsFixed(1)}',
                color: state.exposureCompensation != 0
                    ? const Color(0xFF8EFF71)
                    : (isDark ? Colors.white : Colors.black),
                isDark: isDark,
                onDecrement: () => state.setExposureCompensation(
                  state.exposureCompensation - 0.3,
                ),
                onIncrement: () => state.setExposureCompensation(
                  state.exposureCompensation + 0.3,
                ),
                onTap: () => _showExposureCompensationDialog(context, state),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildFilmSimulationButton(context, state),
        const SizedBox(height: 16),
        _buildNdFilterButton(context, state),
      ],
    );
  }

  Widget _build3DControlBlock({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required VoidCallback onTap,
    bool isLocked = false,
    String? caption,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 84, // Reduced height for insets
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161719) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.black : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          // Sharp Inset shadow for a "carved" look
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.95),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                    blurStyle: BlurStyle.inner,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    blurStyle: BlurStyle.inner,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1, -1),
                    blurRadius: 2,
                    blurStyle: BlurStyle.inner,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF767575),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: onDecrement,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF383838), const Color(0xFF111111)]
                            : [
                                const Color(0xFFFFFFFF),
                                const Color(0xFFE0E0E0),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFFCCCCCC),
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                offset: const Offset(1.5, 2.5),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.1),
                                offset: const Offset(-0.5, -0.5),
                                blurRadius: 1,
                                blurStyle: BlurStyle.inner,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                offset: const Offset(1, 2),
                                blurRadius: 3,
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-1, -1),
                                blurRadius: 1,
                                blurStyle: BlurStyle.inner,
                              ),
                            ],
                    ),
                    child: const Icon(
                      Icons.remove,
                      size: 16,
                      color: Color(0xFF767575),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
                GestureDetector(
                  onTap: onIncrement,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF383838), const Color(0xFF111111)]
                            : [
                                const Color(0xFFFFFFFF),
                                const Color(0xFFE0E0E0),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFFCCCCCC),
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                offset: const Offset(1.5, 2.5),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.1),
                                offset: const Offset(-0.5, -0.5),
                                blurRadius: 1,
                                blurStyle: BlurStyle.inner,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                offset: const Offset(1, 2),
                                blurRadius: 3,
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-1, -1),
                                blurRadius: 1,
                                blurStyle: BlurStyle.inner,
                              ),
                            ],
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Color(0xFF767575),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Duplicated _buildFilmSimulationButton removed

  Widget _buildNdFilterButton(BuildContext context, ExposureState state) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: state.themeMode == ThemeMode.dark
            ? const Color(0xFF191A1A)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.themeMode == ThemeMode.dark
              ? Colors.transparent
              : const Color(0xFFE5E5E5),
          width: 1,
        ),
        boxShadow: state.themeMode == ThemeMode.dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(2, 4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ND FILTER',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: state.themeMode == ThemeMode.dark
                      ? const Color(0xFF767575)
                      : const Color(0xFFA0A0A0),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.ndFilter.label} ${state.ndFilter == NdFilter.none ? '' : '+${ExposureCalculator.getNdStops(state.ndFilter)} STOPS'}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8EFF71),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              // Show ND filter picker dialog
              _showNdFilterPickerDialog(context, state);
            },
            child: Icon(
              Icons.tune,
              color: state.themeMode == ThemeMode.dark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  void _showNdFilterPickerDialog(BuildContext context, ExposureState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: state.themeMode == ThemeMode.dark
          ? const Color(0xFF131313)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT ND FILTER',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: state.themeMode == ThemeMode.dark
                      ? Colors.white
                      : Colors.black,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: NdFilter.values.map((f) {
                  final isSelected = state.ndFilter == f;
                  final isDark = state.themeMode == ThemeMode.dark;
                  return GestureDetector(
                    onTap: () {
                      state.setNdFilter(f);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? state.primaryColor
                            : (isDark
                                  ? const Color(0xFF191A1A)
                                  : const Color(0xFFEEEEEE)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        f.label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black
                              : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilmSimulationButton(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.dark;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FilmDatabaseScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252626) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FILM STOCK',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFFACABAA)
                        : const Color(0xFF757575),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.selectedFilm?.name.toUpperCase() ?? 'NONE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: state.primaryColor,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (state.selectedFilm != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? const Color(0xFFACABAA)
                          : const Color(0xFF757575),
                    ),
                    onPressed: () => state.selectFilm(null),
                  ),
                Icon(
                  Icons.camera_roll,
                  color: isDark
                      ? const Color(0xFFACABAA)
                      : const Color(0xFF757575),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExposureCompensationDialog(
    BuildContext context,
    ExposureState state,
  ) {
    _showExpCompDialog(context, state);
  }

  Widget _buildProBottomNav(BuildContext context, ExposureState state) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF131313).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 8,
                    top: 8,
                    bottom: 8,
                    right: 4,
                  ),
                  decoration: BoxDecoration(
                    color: state.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: state.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.speed, color: Colors.black, size: 28),
                      const SizedBox(height: 2),
                      Text(
                        'MEASURE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SettingsScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0, 1);
                        const end = Offset.zero;
                        const curve = Curves.easeOutQuint;
                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 4,
                    top: 8,
                    bottom: 8,
                    right: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.settings,
                        color: Color(0xFF757575),
                        size: 28,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SETTINGS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF757575),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Components & Dialogs ---

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF484848).withValues(alpha: 0.02)
      ..strokeWidth = 1;
    const double spacing = 20;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

void _showExpCompDialog(BuildContext context, ExposureState state) {
  final isDark = state.themeMode == ThemeMode.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? const Color(0xFF131313) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EXPOSURE COMPENSATION',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: state.primaryColor,
                  onPressed: () => state.setExposureCompensation(
                    state.exposureCompensation - 0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: state.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${state.exposureCompensation >= 0 ? '+' : ''}${state.exposureCompensation.toStringAsFixed(1)} EV',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: state.primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: state.primaryColor,
                  onPressed: () => state.setExposureCompensation(
                    state.exposureCompensation + 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => state.setExposureCompensation(0.0),
              child: Text(
                'RESET TO ZERO',
                style: TextStyle(
                  color: state.primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

void _showSensorSupportAlert(BuildContext context, ExposureState state) {
  final isDark = state.themeMode == ThemeMode.dark;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF131313) : Colors.white,
      title: Text(
        'No Sensor Detected',
        style: GoogleFonts.spaceGrotesk(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'This app requires an ambient light sensor. Your device does not report one. Calculations will be simulated.',
        style: GoogleFonts.spaceGrotesk(
          color: isDark ? const Color(0xFFACABAA) : const Color(0xFF757575),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            state.markSensorAlertShown();
            Navigator.pop(context);
          },
          child: Text(
            'UNDERSTOOD',
            style: TextStyle(color: state.primaryColor),
          ),
        ),
      ],
    ),
  );
}

class HardwareGrainPainter extends CustomPainter {
  final double density;
  HardwareGrainPainter({this.density = 0.2});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(1337);
    final activeColor = Colors.black.withValues(alpha: 0.1);
    final paint = Paint()
      ..color = activeColor
      ..strokeWidth = 1.0;

    int dotCount = (size.width * size.height * density).toInt();
    for (int i = 0; i < dotCount; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
    }

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (int i = 0; i < dotCount ~/ 2; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], highlightPaint);
    }
  }

  @override
  bool shouldRepaint(HardwareGrainPainter oldDelegate) => false;
}

class ColorNoisePainter extends CustomPainter {
  final double density;
  ColorNoisePainter({this.density = 0.2});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(420);

    final redPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;
    final greenPaint = Paint()
      ..color = const Color(0xFF00FF00).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;
    final bluePaint = Paint()
      ..color = const Color(0xFF0000FF).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    int clusterCount = (size.width * size.height * density / 3).toInt();
    for (int i = 0; i < clusterCount; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], redPaint);
      canvas.drawPoints(ui.PointMode.points, [Offset(x + 1, y)], greenPaint);
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y + 1)], bluePaint);
    }
  }

  @override
  bool shouldRepaint(ColorNoisePainter oldDelegate) => false;
}
