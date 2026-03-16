import 'dart:math';

enum CalculationTarget {
  aperture,
  shutter,
  iso,
}

enum NdFilter {
  none('None', 1, 0),
  nd2('ND2', 2, 1),
  nd4('ND4', 4, 2),
  nd8('ND8', 8, 3),
  nd16('ND16', 16, 4),
  nd32('ND32', 32, 5),
  nd64('ND64', 64, 6),
  nd128('ND128', 128, 7),
  nd256('ND256', 256, 8),
  nd512('ND512', 512, 9),
  nd1000('ND1000', 1000, 10);

  final String label;
  final int factor;
  final int stops;
  const NdFilter(this.label, this.factor, this.stops);
}

enum FpsOption {
  fps24('24 fps', 24, 1 / 48),
  fps25('25 fps', 25, 1 / 50),
  fps30('30 fps', 30, 1 / 60),
  fps50('50 fps', 50, 1 / 100),
  fps60('60 fps', 60, 1 / 120);

  final String label;
  final int fps;
  final double shutterSpeed;
  const FpsOption(this.label, this.fps, this.shutterSpeed);
}

class ExposureCalculator {
  // Calibration constant for flat sensor (incident light)
  static const double calibrationConstant = 250.0;

  static const List<int> isoValues = [
    50, 100, 160, 200, 320, 400, 640, 800, 1250, 1600, 3200, 6400, 12800
  ];

  static const List<int> isoValuesHalf = [
    50, 75, 100, 150, 200, 300, 400, 600, 800, 1200, 1600, 2400, 3200, 4800, 6400, 9600, 12800
  ];

  static const List<double> apertureValues = [
    1.0, 1.2, 1.4, 1.8, 2.0, 2.5, 2.8, 3.2, 4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 11.0, 13.0, 16.0, 22.0
  ];

  static const List<double> apertureValuesHalf = [
    1.0, 1.2, 1.4, 1.7, 2.0, 2.4, 2.8, 3.3, 4.0, 4.8, 5.6, 6.7, 8.0, 9.5, 11.0, 13.0, 16.0, 19.0, 22.0
  ];

  static const List<double> shutterValues = [
    1 / 8000, 1 / 4000, 1 / 2000, 1 / 1000, 1 / 500, 1 / 250, 1 / 125, 1 / 120, 1 / 100, 1 / 60, 1 / 50, 1 / 48, 1 / 30, 1 / 15, 1 / 8, 1 / 4, 1 / 2, 1, 2, 4, 8, 15, 30
  ];

  static const List<double> shutterValuesHalf = [
    1 / 8000, 1 / 6000, 1 / 4000, 1 / 3000, 1 / 2000, 1 / 1500, 1 / 1000, 1 / 750, 1 / 500, 1 / 350, 1 / 250, 1 / 180, 1 / 125, 1 / 120, 1 / 100, 1 / 90, 1 / 60, 1 / 50, 1 / 48, 1 / 45, 1 / 30, 1 / 20, 1 / 15, 1 / 10, 1 / 8, 1 / 6, 1 / 4, 0.3, 0.5, 0.7, 1, 1.5, 2, 3, 4, 6, 8, 12, 15, 24, 30
  ];

  /// Format shutter speed for display (e.g., "1/50", "1/4000", or "2s")
  static String formatShutterSpeed(double value) {
    if (value >= 1.0) {
      if (value == value.roundToDouble()) {
        return '${value.toInt()}s';
      }
      return '${value.toStringAsFixed(1)}s';
    }
    // Handle small precision issues
    double denominator = 1 / value;
    return '1/${denominator.round()}';
  }

  /// Format aperture
  static String formatAperture(double value) {
    if (value == value.roundToDouble()) {
      return 'f/${value.toInt()}';
    }
    return 'f/${value.toStringAsFixed(1)}';
  }

  /// Calculates Base EV at ISO 100 for display (standard notation)
  static double calculateEv(double lux, {NdFilter ndFilter = NdFilter.none}) {
    if (lux <= 0) return 0;
    // compensate for ND filter (effective lux = lux / factor)
    double effectiveLux = lux / ndFilter.factor;
    // EV at ISO 100
    // 2^EV = (Lux * 100) / C
    return log((effectiveLux * 100) / calibrationConstant) / ln2;
  }

  /// Find the closest predefined value
  static T findClosest<T extends num>(double target, List<T> values) {
    if (values.isEmpty) return target as T;
    return values.reduce((a, b) =>
        (a.toDouble() - target).abs() < (b.toDouble() - target).abs() ? a : b);
  }

  /// Core formula based on: (N^2)/t = (Lux * ISO) / C
  /// Meaning: Target = remaining var

  static double calculateAperture(double lux, double shutterSpeed, int iso, {NdFilter ndFilter = NdFilter.none, bool halfSteps = false}) {
    List<double> options = halfSteps ? apertureValuesHalf : apertureValues;
    if (lux <= 0 || shutterSpeed <= 0) return options.first;
    double effectiveLux = lux / ndFilter.factor;
    
    // N^2 = (Lux * ISO * t) / C
    double nSquared = (effectiveLux * iso * shutterSpeed) / calibrationConstant;
    if (nSquared <= 0) return options.first;
    
    double exactAperture = sqrt(nSquared);
    return findClosest(exactAperture, options);
  }

  static double calculateShutterSpeed(double lux, double aperture, int iso, {NdFilter ndFilter = NdFilter.none, bool halfSteps = false}) {
    List<double> options = halfSteps ? shutterValuesHalf : shutterValues;
    if (lux <= 0) return options.first;
    double effectiveLux = lux / ndFilter.factor;
    
    // t = (N^2 * C) / (Lux * ISO)
    double exactShutter = (aperture * aperture * calibrationConstant) / (effectiveLux * iso);
    return findClosest(exactShutter, options);
  }

  static int calculateIso(double lux, double aperture, double shutterSpeed, {NdFilter ndFilter = NdFilter.none, bool halfSteps = false}) {
    List<int> options = halfSteps ? isoValuesHalf : isoValues;
    if (lux <= 0 || shutterSpeed <= 0) return options.first;
    double effectiveLux = lux / ndFilter.factor;
    if (effectiveLux <= 0) return options.first;
    
    // ISO = (N^2 * C) / (Lux * t)
    double exactIso = (aperture * aperture * calibrationConstant) / (effectiveLux * shutterSpeed);
    return findClosest(exactIso, options);
  }
}
