import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';
import 'exposure_state.dart';
import 'ui_helpers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExposureState>();
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;
    final backgroundColor = isDark
        ? (state.isPureBlack ? Colors.black : const Color(0xFF1A1B1E))
        : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, state),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Appearance'),
                    const SizedBox(height: 8),
                    _buildAppearanceCard(context, state),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Sensor Configuration'),
                    const SizedBox(height: 8),
                    _buildSensorCard(context, state),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;
    final bgColor = isDark
        ? (state.isPureBlack ? Colors.black : const Color(0xFF1A1B1E))
        : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131313) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.02),
                    offset: const Offset(1, 1),
                    blurRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(-1, -1),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDark ? const Color(0xFFE7E5E5) : Colors.black,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                'LELEMETER',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: isDark ? const Color(0xFFE7E5E5) : Colors.black,
                ),
              ),
              Text(
                'v2.0.0',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 10,
                  letterSpacing: 2,
                  color: const Color(0xFFACABAA),
                ),
              ),
            ],
          ),
          const SizedBox(width: 48), // Spacer for centering
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(fontFamily: 'SpaceGrotesk', 
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFACABAA),
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? (state.isPureBlack ? Colors.black : const Color(0xFF131313)) : Colors.white,
        image: skeuomorphicNoise,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _build3DPushButton(
                    context: context,
                    icon: Icons.devices,
                    label: 'SYSTEM',
                    isActive: state.themeMode == ThemeMode.system,
                    activeColor: state.primaryColor,
                    onTap: () {
                      state.setThemeMode(ThemeMode.system);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _build3DPushButton(
                    context: context,
                    icon: Icons.light_mode,
                    label: 'LIGHT',
                    isActive: state.themeMode == ThemeMode.light,
                    activeColor: const Color(0xFF8EFF71),
                    onTap: () {
                      state.setThemeMode(ThemeMode.light);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _build3DPushButton(
                    context: context,
                    icon: Icons.dark_mode,
                    label: 'DARK',
                    isActive: state.themeMode == ThemeMode.dark,
                    activeColor: const Color(0xFFEE7D77),
                    onTap: () {
                      state.setThemeMode(ThemeMode.dark);
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isDark ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                _buildToggleRow(
                  icon: Icons.contrast,
                  title: 'Pure Black (OLED)',
                  subtitle: 'Saves battery',
                  isActive: state.isPureBlack,
                  activeColor: state.primaryColor,
                  isDark: isDark,
                  onToggle: () {
                    state.togglePureBlack();
                  },
                ),
                Container(
                  height: 1,
                  color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.1),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          _buildToggleRow(
            icon: Icons.fullscreen,
            title: 'Fullscreen Mode',
            subtitle: 'Hide system status bar',
            isActive: state.hideStatusBar,
            activeColor: state.primaryColor,
            isDark: isDark,
            onToggle: () {
              state.toggleStatusBar();
            },
          ),
          Container(
            height: 1,
            color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          _buildToggleRow(
            icon: Icons.unfold_more,
            title: '1/2 Stop Increments',
            subtitle: 'Allow finer ISO/f-stop/Shutter steps',
            isActive: state.useHalfSteps,
            activeColor: state.primaryColor,
            isDark: isDark,
            onToggle: () {
              state.toggleHalfSteps();
            },
          ),
          Container(
            height: 1,
            color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          _buildActionRow(
            icon: Icons.palette,
            title: 'Accent Color',
            subtitle: 'Tap to change',
            iconColor: state.primaryColor,
            isDark: isDark,
            onTap: () {
              _showColorPicker(context, state);
            },
          ),
          Container(
            height: 1,
            color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          _buildToggleRow(
            icon: Icons.color_lens_outlined,
            title: 'Use System Accent (Monet)',
            subtitle: 'Android 12+ dynamic colors',
            isActive: state.useDynamicColor,
            activeColor: state.primaryColor,
            isDark: isDark,
            onToggle: () {
              state.toggleUseDynamicColor();
            },
          ),
          Container(
            height: 1,
            color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          _buildToggleRow(
            icon: Icons.blur_on,
            title: 'Glassmorphism (Blur Effects)',
            subtitle: 'Toggle backdrop blur',
            isActive: state.enableBlur,
            activeColor: state.primaryColor,
            isDark: isDark,
            onToggle: () {
              state.toggleBlur();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(BuildContext context, ExposureState state) {
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;

    return Column(
      children: [
        // Manual Calibration Block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? (state.isPureBlack ? Colors.black : const Color(0xFF131313)) : Colors.white,
            image: skeuomorphicNoise,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.black : Colors.grey.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                offset: const Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CALIBRATION FACTOR',
                    style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFFACABAA),
                    ),
                  ),
                  Text(
                    'x${state.calibrationFactor.toStringAsFixed(2)}',
                    style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: state.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAdjustButton(
                    icon: Icons.remove,
                    isDark: isDark,
                    onTap: () => state.setCalibrationFactor(
                      state.calibrationFactor - 0.1,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tune sensor sensitivity. Higher value = Brighter exposure reading.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                    fontFamily: 'Inter',
                          fontSize: 10,
                          color: const Color(0xFF767575),
                        ),
                      ),
                    ),
                  ),
                  _buildAdjustButton(
                    icon: Icons.add,
                    isDark: isDark,
                    onTap: () => state.setCalibrationFactor(
                      state.calibrationFactor + 0.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Hardware Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HARDWARE STATUS',
                          style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: const Color(0xFF767575),
                          ),
                        ),
                        if (state.sensorName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            state.sensorName!.toUpperCase(),
                            style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: state.hasSensor ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: state.hasSensor ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      state.hasSensor ? 'SENSOR DETECTED' : 'SENSOR NOT DETECTED',
                      style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: state.hasSensor ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Reset Sensor Button
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        state.resetCalibration();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sensor calibration reset.',
                              style: TextStyle(fontFamily: 'SpaceGrotesk', color: Colors.white),
                            ),
                            backgroundColor: state.primaryColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF252626)
                              : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'RESET CALIB',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        state.resetSensor();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Reinitializing sensor hardware...',
                              style: TextStyle(fontFamily: 'SpaceGrotesk', color: Colors.white),
                            ),
                            backgroundColor: state.primaryColor, // Use actual current primary
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF252626)
                              : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: state.primaryColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'RESET SENSOR',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Factory Reset Block
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: isDark
                    ? const Color(0xFF1A1B1E)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xFFEE7D77).withValues(alpha: 0.4),
                  ),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFEE7D77), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'RESET DEFAULTS',
                      style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEE7D77),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'This will wipe ALL settings and restart the app.\n\nYour film selection, calibration, and theme will be lost.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFACABAA)
                        : const Color(0xFF767575),
                    height: 1.5,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF9D9E9E)
                            : const Color(0xFF767575),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      state.resetAndRestart();
                    },
                    child: Text(
                      'RESET & RESTART',
                      style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEE7D77),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131313) : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF191A1A) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restart_alt, color: Color(0xFFEE7D77)),
                  const SizedBox(width: 8),
                  Text(
                    'RESET DEFAULTS',
                    style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFFEE7D77),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252626) : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF252626)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          offset: const Offset(1, 1),
                          blurRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(-1, -1),
                          blurRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isActive ? activeColor : const Color(0xFF9D9E9E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                    fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE7E5E5) : Colors.black,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                    fontFamily: 'Inter',
                        fontSize: 12,
                        color: const Color(0xFFACABAA),
                      ),
                    ),
                ],
              ),
            ),
            _buildSwitch(isActive, activeColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF252626)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                    fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE7E5E5) : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                    fontFamily: 'Inter',
                      fontSize: 12,
                      color: const Color(0xFFACABAA),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFFACABAA)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(bool isActive, Color activeColor, bool isDark) {
    return Container(
      width: 56,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: isActive ? 24 : 0,
            right: isActive ? 0 : 24,
            top: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive ? activeColor : const Color(0xFF2B2C2C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ExposureState state) {
    Color pickerColor = state.primaryColor;
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131313) : Colors.white,
        title: Text(
          'CHOOSE THEME COLOR',
          style: TextStyle(fontFamily: 'SpaceGrotesk', 
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              state.setPrimaryColor(pickerColor);
              Navigator.pop(context);
            },
            child: Text('SELECT', style: TextStyle(color: state.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _build3DPushButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final state = context.watch<ExposureState>();
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
                ? [activeColor, activeColor.withValues(alpha: 0.7)]
                : (isDark
                    ? [const Color(0xFF333333), const Color(0xFF191A1A)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFDCDCDC)]),
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.8)
                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFD4D4D4)),
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: state.isPureBlack
                          ? (isActive ? 0.9 : 0.7)
                          : (isActive ? 0.5 : 0.3),
                    ),
                    offset: isActive ? const Offset(2, 2) : const Offset(4, 6),
                    blurRadius: isActive ? 4 : 8,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                  ),
                  if (isActive)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      offset: const Offset(0, 2),
                      blurStyle: BlurStyle.inner,
                    ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: isActive ? const Offset(1, 2) : const Offset(2, 4),
                    blurRadius: isActive ? 4 : 8,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1, -1),
                    blurRadius: 2,
                  ),
                  if (isActive)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      offset: const Offset(0, 2),
                      blurStyle: BlurStyle.inner,
                    ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? Colors.black.withValues(alpha: 0.8)
                  : (isDark ? const Color(0xFFACABAA) : const Color(0xFF767575)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontFamily: 'SpaceGrotesk', 
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isActive
                    ? Colors.black.withValues(alpha: 0.8)
                    : (isDark ? const Color(0xFFACABAA) : const Color(0xFF767575)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
