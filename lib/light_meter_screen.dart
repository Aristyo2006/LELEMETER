import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'exposure_state.dart';
import 'exposure_calculator.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class LightMeterScreen extends StatelessWidget {
  const LightMeterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LELEMETER',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.settings,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onPressed: () {
              _showAdvancedSettings(context);
            },
          ),
        ],
      ),
      body: Consumer<ExposureState>(
        builder: (context, state, child) {
          if (!state.isInitialized) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.amber)),
            );
          }

          // Show alert if no sensor detected (once per session)
          if (!state.hasSensor && !state.hasShownSensorAlert) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSensorSupportAlert(context, state);
            });
          }

          if (state.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!state.isListening && state.currentLux == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildTopSection(context, state),
              Divider(
                height: 1,
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  children: [
                    state.useDialUi
                        ? _ExposureDial<int>(
                            title: 'ISO',
                            target: CalculationTarget.iso,
                            currentValue: state.iso,
                            values: state.isoValues,
                            isTarget: state.target == CalculationTarget.iso,
                            onTargetSelected: () =>
                                state.setTarget(CalculationTarget.iso),
                            onValueChanged: (val) => state.setIso(val),
                            formatValue: (v) => v.toString(),
                          )
                        : _buildExposureParameter(
                            context: context,
                            title: 'ISO',
                            target: CalculationTarget.iso,
                            currentValue: state.iso,
                            values: state.isoValues,
                            isTarget: state.target == CalculationTarget.iso,
                            onTargetSelected: () =>
                                state.setTarget(CalculationTarget.iso),
                            onValueChanged: (val) => state.setIso(val),
                            formatValue: (v) => v.toString(),
                          ),
                    const SizedBox(height: 24),
                    state.useDialUi
                        ? _ExposureDial<double>(
                            title: 'APERTURE',
                            target: CalculationTarget.aperture,
                            currentValue: state.aperture,
                            values: state.apertureValues,
                            isTarget:
                                state.target == CalculationTarget.aperture,
                            onTargetSelected: () =>
                                state.setTarget(CalculationTarget.aperture),
                            onValueChanged: (val) => state.setAperture(val),
                            formatValue: (v) =>
                                v.toString(), // Simplified format, no 'f/'
                          )
                        : _buildExposureParameter(
                            context: context,
                            title: 'APERTURE',
                            target: CalculationTarget.aperture,
                            currentValue: state.aperture,
                            values: state.apertureValues,
                            isTarget:
                                state.target == CalculationTarget.aperture,
                            onTargetSelected: () =>
                                state.setTarget(CalculationTarget.aperture),
                            onValueChanged: (val) => state.setAperture(val),
                            formatValue: (v) =>
                                ExposureCalculator.formatAperture(v),
                          ),
                    const SizedBox(height: 24),
                    state.useDialUi
                        ? _ExposureDial<double>(
                            title: 'SHUTTER',
                            target: CalculationTarget.shutter,
                            currentValue: state.shutterSpeed,
                            values: state.shutterValues,
                            isTarget: state.target == CalculationTarget.shutter,
                            onTargetSelected: () =>
                                state.setTarget(CalculationTarget.shutter),
                            onValueChanged: (val) => state.setShutterSpeed(val),
                            formatValue: (v) =>
                                ExposureCalculator.formatShutterSpeed(v),
                            isLockedByVideo: state.fpsOption != null,
                          )
                        : _buildExposureParameter(
                            context: context,
                            title: 'SHUTTER',
                            target: CalculationTarget.shutter,
                            currentValue: state.shutterSpeed,
                            values: state.shutterValues,
                            isTarget: state.target == CalculationTarget.shutter,
                            onTargetSelected: () =>
                                state.setTarget(CalculationTarget.shutter),
                            onValueChanged: (val) => state.setShutterSpeed(val),
                            formatValue: (v) =>
                                ExposureCalculator.formatShutterSpeed(v),
                            isLockedByVideo: state.fpsOption != null,
                          ),
                    const SizedBox(height: 24),
                    state.useDialUi
                        ? _ExposureDial<NdFilter>(
                            title: 'ND FILTER',
                            target: CalculationTarget.shutter, // Ignore
                            currentValue: state.ndFilter,
                            values: NdFilter.values,
                            isTarget: false,
                            onTargetSelected: () {}, // Ignore
                            onValueChanged: (val) => state.setNdFilter(val),
                            formatValue: (v) => v.label,
                            showTargetToggle: false,
                          )
                        : _buildExposureParameter(
                            context: context,
                            title: 'ND FILTER',
                            target: CalculationTarget.shutter, // Ignore
                            currentValue: state.ndFilter,
                            values: NdFilter.values,
                            isTarget: false,
                            onTargetSelected: () {}, // Ignore
                            onValueChanged: (val) => state.setNdFilter(val),
                            formatValue: (v) => v.label,
                            showTargetToggle: false,
                          ),
                  ],
                ),
              ),
              if (state.showBottomBar) _buildToolsSection(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, ExposureState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EV',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  state.ev.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.effectiveLux.toStringAsFixed(0)} LUX',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: state.toggleLock,
              borderRadius: BorderRadius.circular(40),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.isLocked
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).dividerColor.withOpacity(0.05),
                ),
                child: Icon(
                  state.isLocked ? LucideIcons.lock : LucideIcons.unlock,
                  color: state.isLocked
                      ? Colors.black
                      : Theme.of(context).iconTheme.color,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureParameter<T>({
    required BuildContext context,
    required String title,
    required CalculationTarget target,
    required T currentValue,
    required List<T> values,
    required bool isTarget,
    required VoidCallback onTargetSelected,
    required Function(T) onValueChanged,
    required String Function(T) formatValue,
    bool isLockedByVideo = false,
    bool showTargetToggle = true,
  }) {
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                letterSpacing: 2,
              ),
            ),
            if (isLockedByVideo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.video, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'FPS LOCKED',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (showTargetToggle)
              GestureDetector(
                onTap: onTargetSelected,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isTarget
                        ? primary
                        : Theme.of(context).dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isTarget ? 'AUTO' : 'SELECT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: isTarget
                          ? Colors.black
                          : Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (isTarget)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                formatValue(currentValue),
                style: TextStyle(
                  fontSize: 32,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: values.map((val) {
                final isSelected = (val == currentValue);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (!isLockedByVideo) onValueChanged(val);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Theme.of(context).dividerColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.1),
                              ),
                      ),
                      child: Text(
                        formatValue(val),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Theme.of(context).scaffoldBackgroundColor
                              : (isLockedByVideo
                                    ? Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.3)
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context, ExposureState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Only display FPS video tools now, ND Filter is moved to Dial List
            _ToolButton(
              icon: LucideIcons.video,
              label: state.fpsOption == null
                  ? 'FPS RULE'
                  : state.fpsOption!.label,
              isActive: state.fpsOption != null,
              onTap: () => _showFpsDialog(context, state),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdvancedSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<ExposureState>(
        builder: (context, state, child) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(LucideIcons.x, size: 28),
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ListTile(
                        leading: Icon(LucideIcons.info,
                            color: Theme.of(context).iconTheme.color),
                        title: Text('About LELEMETER',
                            style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color)),
                        subtitle: Text(
                          'Minimal Light Meter Based from your Lux sensor\nFlat Sensor Calibration: C=250.0',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withAlpha(150)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Dark Mode'),
                            secondary: const Icon(LucideIcons.moon),
                            value: state.themeMode == ThemeMode.dark,
                            activeColor: state.primaryColor,
                            onChanged: (val) {
                              state.toggleTheme();
                            },
                          ),
                          if (state.themeMode == ThemeMode.dark)
                            Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Pure Black'),
                                  subtitle: Text(
                                    'Uses absolute black for OLED screens to save battery and increase contrast.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                    ),
                                  ),
                                  secondary: const Icon(LucideIcons.layers),
                                  value: state.isPureBlack,
                                  activeColor: state.primaryColor,
                                  onChanged: (val) {
                                    state.togglePureBlack();
                                  },
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showColorPicker(context, state),
                                icon: const Icon(LucideIcons.palette, size: 20, color: Colors.black),
                                label: const Text(
                                  'CUSTOMIZE ACCENT COLOR',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: state.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Haptic Feedback'),
                            secondary: const Icon(LucideIcons.smartphone),
                            value: state.hapticsEnabled,
                            activeColor: state.primaryColor,
                            onChanged: (val) {
                              state.toggleHaptics();
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Analog Dial Style'),
                            secondary: const Icon(LucideIcons.mousePointerClick),
                            value: state.useDialUi,
                            activeColor: state.primaryColor,
                            onChanged: (val) {
                              state.toggleDialStyle();
                            },
                          ),
                          SwitchListTile(
                            title: const Text('1/2 EV Steps'),
                            secondary: const Icon(LucideIcons.sliders),
                            value: state.useHalfSteps,
                            activeColor: state.primaryColor,
                            onChanged: (val) {
                              state.toggleHalfSteps();
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Show FPS Tools Panel'),
                            secondary: const Icon(Icons.arrow_drop_down_circle),
                            value: state.showBottomBar,
                            activeColor: state.primaryColor,
                            onChanged: (val) {
                              state.toggleBottomBar();
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Show Status Bar'),
                            secondary: const Icon(LucideIcons.maximize),
                            value: state.showStatusBar,
                            activeColor: state.primaryColor,
                            onChanged: (val) {
                              state.toggleStatusBar();
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sensor Diagnostics',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDiagnosticRow(
                              context,
                              'Status',
                              state.hasSensor ? 'Hardware Detected' : 'No Hardware Found',
                              state.hasSensor ? Colors.green : Colors.red,
                            ),
                            _buildDiagnosticRow(
                              context,
                              'Signal',
                              state.isListening ? 'Stream Active' : 'Stream Closed',
                              state.isListening ? Colors.green : Colors.orange,
                            ),
                            _buildDiagnosticRow(
                              context,
                              'Last Update',
                              state.lastUpdate != null
                                  ? '${DateTime.now().difference(state.lastUpdate!).inSeconds}s ago'
                                  : 'Never',
                              Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(LucideIcons.refreshCw, size: 16),
                                label: const Text('Reset Light Sensor'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).primaryColor,
                                  side: BorderSide(color: Theme.of(context).primaryColor),
                                ),
                                onPressed: () => state.reinitializeSensor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // _showNdFilterDialog removed as it's now a dial

  Widget _buildDiagnosticRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }



  void _showSensorSupportAlert(BuildContext context, ExposureState state) {
    state.markSensorAlertShown();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.red),
            const SizedBox(width: 12),
            const Text('Sensor Missing', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Your device does not seem to have a physical light sensor, or it is not accessible. LELEMETER requires this sensor to measure light.\n\nNote: Emulators and some tablets do not have light sensors.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I UNDERSTAND', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ExposureState state) {
    Color pickerColor = state.primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Pick Accent Color', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pickerColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              state.setPrimaryColor(pickerColor);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showFpsDialog(BuildContext context, ExposureState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<ExposureState>(
        builder: (context, state, child) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Video FPS Rule (180° Shutter)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withAlpha(150),
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Off (Photo Mode)'),
                    trailing: state.fpsOption == null
                        ? const Icon(LucideIcons.check, color: Colors.amber)
                        : null,
                    onTap: () {
                      state.setFpsOption(null);
                      Navigator.pop(context);
                    },
                  ),
                  ...FpsOption.values.map((fps) {
                    return ListTile(
                      title: Text(fps.label),
                      subtitle: Text(
                        'Locks shutter to ${ExposureCalculator.formatShutterSpeed(fps.shutterSpeed)}',
                      ),
                      trailing: state.fpsOption == fps
                          ? const Icon(LucideIcons.check, color: Colors.amber)
                          : null,
                      onTap: () {
                        state.setFpsOption(fps);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).primaryColor
        : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExposureDial<T> extends StatefulWidget {
  final String title;
  final CalculationTarget target;
  final T currentValue;
  final List<T> values;
  final bool isTarget;
  final VoidCallback onTargetSelected;
  final Function(T) onValueChanged;
  final String Function(T) formatValue;
  final bool isLockedByVideo;
  final bool showTargetToggle;

  const _ExposureDial({
    required this.title,
    required this.target,
    required this.currentValue,
    required this.values,
    required this.isTarget,
    required this.onTargetSelected,
    required this.onValueChanged,
    required this.formatValue,
    this.isLockedByVideo = false,
    this.showTargetToggle = true,
  });

  @override
  State<_ExposureDial<T>> createState() => _ExposureDialState<T>();
}

class _ExposureDialState<T> extends State<_ExposureDial<T>> {
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    int initialIndex = widget.values.indexOf(widget.currentValue);
    if (initialIndex == -1) initialIndex = 0;
    _scrollController = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(covariant _ExposureDial<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      _scrollController.dispose();
      _initController();
    } else if (oldWidget.currentValue != widget.currentValue) {
      int targetIndex = widget.values.indexOf(widget.currentValue);
      if (targetIndex != -1 && _scrollController.hasClients) {
        if (widget.isTarget || widget.isLockedByVideo) {
          _scrollController.animateToItem(
            targetIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else if (_scrollController.selectedItem != targetIndex) {
          _scrollController.jumpToItem(targetIndex);
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                letterSpacing: 2,
              ),
            ),
            if (widget.isLockedByVideo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.video, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'FPS LOCKED',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.showTargetToggle)
              GestureDetector(
                onTap: widget.onTargetSelected,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isTarget
                        ? primary
                        : Theme.of(context).dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.isTarget ? 'AUTO' : 'SELECT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: widget.isTarget
                          ? Colors.black
                          : Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AbsorbPointer(
          absorbing: widget.isTarget || widget.isLockedByVideo,
          child: Opacity(
            opacity: widget.isLockedByVideo ? 0.3 : 1.0,
            child: widget.isTarget ? _buildAutoDisplay(primary) : _buildDial(),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoDisplay(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          widget.formatValue(widget.currentValue),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDial() {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Render a custom Analog Dial background
          Container(
            width: 140,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 140,
              height: double.infinity,
              foregroundDecoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
              child: RotatedBox(
                quarterTurns: -1,
                child: ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 80,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.8,
                  magnification: 1.3,
                  useMagnifier: true,
                  onSelectedItemChanged: (index) {
                    if (!widget.isLockedByVideo && !widget.isTarget) {
                      widget.onValueChanged(widget.values[index]);
                    }
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.values.length,
                    builder: (context, index) {
                      final val = widget.values[index];
                      final isSelected = val == widget.currentValue;
                      return RotatedBox(
                        quarterTurns: 1,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.formatValue(val),
                                maxLines: 1,
                                style: TextStyle(
                              fontSize: 24,
                              fontFamily: 'Courier',
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Red alignment tick mark for the dial
          Positioned(
            top: 4,
            child: Container(width: 2, height: 10, color: Colors.red),
          ),
          Positioned(
            bottom: 4,
            child: Container(width: 2, height: 10, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
