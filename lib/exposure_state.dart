import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:light/light.dart';
import 'exposure_calculator.dart';

class ExposureState extends ChangeNotifier {
  Light? _light;
  StreamSubscription<int>? _subscription;

  double _currentLux = 0.0;
  double get currentLux => _currentLux;

  double _lockedLux = 0.0;
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  double get effectiveLux => _isLocked ? _lockedLux : _currentLux;

  // Settings
  int _iso = ExposureCalculator.isoValues[2]; // 160
  double _aperture = ExposureCalculator.apertureValues[6]; // 2.8
  double _shutterSpeed = ExposureCalculator.shutterValues[10]; // 1/30

  // Standard EV
  double get ev => ExposureCalculator.calculateEv(effectiveLux, ndFilter: _ndFilter);

  int get iso => _iso;
  double get aperture => _aperture;
  double get shutterSpeed => _shutterSpeed;

  CalculationTarget _target = CalculationTarget.shutter;
  CalculationTarget get target => _target;

  NdFilter _ndFilter = NdFilter.none;
  NdFilter get ndFilter => _ndFilter;

  FpsOption? _fpsOption;
  FpsOption? get fpsOption => _fpsOption;

  bool _isListening = false;
  bool get isListening => _isListening;
  
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool _hapticsEnabled = true;
  bool get hapticsEnabled => _hapticsEnabled;

  bool _useDialUi = true;
  bool get useDialUi => _useDialUi;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _triggerHaptic(light: true);
    notifyListeners();
  }

  void toggleHaptics() {
    _hapticsEnabled = !_hapticsEnabled;
    _triggerHaptic();
    notifyListeners();
  }

  void toggleDialStyle() {
    _useDialUi = !_useDialUi;
    _triggerHaptic();
    notifyListeners();
  }

  void _triggerHaptic({bool light = false}) {
    if (_hapticsEnabled) {
      if (light) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  ExposureState() {
    _initSensor();
  }

  void _initSensor() {
    try {
      _light = Light();
      _subscription = _light?.lightSensorStream.listen((int luxValue) {
        if (!_isLocked) {
          _currentLux = luxValue.toDouble();
          _recalculate();
          notifyListeners();
        }
      }, onError: (Object error) {
        _errorMessage = 'Sensor error: $error';
        notifyListeners();
      });
      _isListening = true;
    } catch (e) {
      _errorMessage = 'Could not initialize light sensor: $e';
    }
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    if (_isLocked) {
      _lockedLux = _currentLux;
    } else {
      _recalculate();
    }
    notifyListeners();
  }

  void setTarget(CalculationTarget newTarget) {
    if (_target != newTarget) {
      _target = newTarget;
      _triggerHaptic();
      _recalculate();
      notifyListeners();
    }
  }

  void setIso(int newIso) {
    if (_iso != newIso) {
      _iso = newIso;
      _triggerHaptic();
      if (_target == CalculationTarget.iso) {
        _target = CalculationTarget.shutter;
      }
      _recalculate();
    }
    notifyListeners();
  }

  void setAperture(double newAperture) {
    if (_aperture != newAperture) {
      _aperture = newAperture;
      _triggerHaptic();
      if (_target == CalculationTarget.aperture) {
        _target = CalculationTarget.shutter;
      }
      _recalculate();
    }
    notifyListeners();
  }

  void setShutterSpeed(double newShutter) {
    if (_fpsOption != null) return; // Locked by video mode
    if (_shutterSpeed != newShutter) {
      _shutterSpeed = newShutter;
      _triggerHaptic();
      if (_target == CalculationTarget.shutter) {
        _target = CalculationTarget.iso;
      }
      _recalculate();
    }
    notifyListeners();
  }

  void setNdFilter(NdFilter filter) {
    if (_ndFilter != filter) {
      _ndFilter = filter;
      _triggerHaptic();
      _recalculate();
    }
    notifyListeners();
  }

  void setFpsOption(FpsOption? option) {
    if (_fpsOption != option) {
      _fpsOption = option;
      _triggerHaptic();
      if (option != null) {
        _shutterSpeed = option.shutterSpeed;
        if (_target == CalculationTarget.shutter) {
          _target = CalculationTarget.iso; // Cannot calculate shutter if it's locked to FPS
        }
      }
      _recalculate();
    }
    notifyListeners();
  }

  void _recalculate() {
    if (effectiveLux <= 0) return;

    switch (_target) {
      case CalculationTarget.shutter:
        if (_fpsOption == null) {
          _shutterSpeed = ExposureCalculator.calculateShutterSpeed(effectiveLux, _aperture, _iso, ndFilter: _ndFilter);
        } else {
          // If FPS is locked but target is shutter, fallback to calculating ISO
          _target = CalculationTarget.iso;
          _iso = ExposureCalculator.calculateIso(effectiveLux, _aperture, _shutterSpeed, ndFilter: _ndFilter);
        }
        break;
      case CalculationTarget.aperture:
        _aperture = ExposureCalculator.calculateAperture(effectiveLux, _shutterSpeed, _iso, ndFilter: _ndFilter);
        break;
      case CalculationTarget.iso:
        _iso = ExposureCalculator.calculateIso(effectiveLux, _aperture, _shutterSpeed, ndFilter: _ndFilter);
        break;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
