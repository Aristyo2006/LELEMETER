import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ambient_light/ambient_light.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exposure_calculator.dart';

class ExposureState extends ChangeNotifier {
  StreamSubscription<double>? _subscription;
  bool _hasSensor = true;
  bool get hasSensor => _hasSensor;
  
  DateTime? _lastUpdate;
  DateTime? get lastUpdate => _lastUpdate;
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  bool _hasShownSensorAlert = false;
  bool get hasShownSensorAlert => _hasShownSensorAlert;

  void markSensorAlertShown() {
    _hasShownSensorAlert = true;
    notifyListeners();
  }

  double _currentLux = 0.0;
  double get currentLux => _currentLux;

  double _lockedLux = 0.0;
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  double _calibrationFactor = 1.0;
  double get calibrationFactor => _calibrationFactor;

  double get effectiveLux => (_isLocked ? _lockedLux : _currentLux) * _calibrationFactor;

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

  bool _useHalfSteps = false;
  bool get useHalfSteps => _useHalfSteps;

  bool _showBottomBar = true;
  bool get showBottomBar => _showBottomBar;

  bool _isPureBlack = true;
  bool get isPureBlack => _isPureBlack;

  bool _showStatusBar = true;
  bool get showStatusBar => _showStatusBar;

  Color _primaryColor = const Color(0xFFFFB300); // Default Amber
  Color get primaryColor => _primaryColor;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    _triggerHaptic(light: true);
    notifyListeners();
  }

  void toggleHaptics() {
    _hapticsEnabled = !_hapticsEnabled;
    _prefs.setBool('hapticsEnabled', _hapticsEnabled);
    _triggerHaptic();
    notifyListeners();
  }

  void toggleDialStyle() {
    _useDialUi = !_useDialUi;
    _prefs.setBool('useDialUi', _useDialUi);
    _triggerHaptic();
    notifyListeners();
  }

  void toggleHalfSteps() {
    _useHalfSteps = !_useHalfSteps;
    _prefs.setBool('useHalfSteps', _useHalfSteps);
    _triggerHaptic();
    
    // Nearest valid value correction logic goes here
    _iso = ExposureCalculator.findClosest(_iso.toDouble(), isoValues).toInt();
    _aperture = ExposureCalculator.findClosest(_aperture, apertureValues);
    _shutterSpeed = ExposureCalculator.findClosest(_shutterSpeed, shutterValues);
    
    _recalculate();
    notifyListeners();
  }

  void toggleBottomBar() {
    _showBottomBar = !_showBottomBar;
    _prefs.setBool('showBottomBar', _showBottomBar);
    _triggerHaptic();
    notifyListeners();
  }

  void togglePureBlack() {
    _isPureBlack = !_isPureBlack;
    _prefs.setBool('isPureBlack', _isPureBlack);
    _triggerHaptic();
    notifyListeners();
  }

  void toggleStatusBar() {
    _showStatusBar = !_showStatusBar;
    _prefs.setBool('showStatusBar', _showStatusBar);
    _applyStatusBar();
    _triggerHaptic();
    notifyListeners();
  }

  void _applyStatusBar() {
    if (_showStatusBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    _prefs.setInt('primaryColor', color.value);
    _triggerHaptic();
    notifyListeners();
  }

  void setCalibrationFactor(double factor) {
    _calibrationFactor = factor;
    _prefs.setDouble('calibrationFactor', factor);
    _recalculate();
    notifyListeners();
  }

  List<int> get isoValues => _useHalfSteps ? ExposureCalculator.isoValuesHalf : ExposureCalculator.isoValues;
  List<double> get apertureValues => _useHalfSteps ? ExposureCalculator.apertureValuesHalf : ExposureCalculator.apertureValues;
  List<double> get shutterValues => _useHalfSteps ? ExposureCalculator.shutterValuesHalf : ExposureCalculator.shutterValues;

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
    _initPrefsAndSensor();
  }

  Future<void> _initPrefsAndSensor() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load saved settings
    _themeMode = (_prefs.getBool('isDarkMode') ?? true) ? ThemeMode.dark : ThemeMode.light;
    _hapticsEnabled = _prefs.getBool('hapticsEnabled') ?? true;
    _useDialUi = _prefs.getBool('useDialUi') ?? true;
    _useHalfSteps = _prefs.getBool('useHalfSteps') ?? false;
    _showBottomBar = _prefs.getBool('showBottomBar') ?? true;
    _isPureBlack = _prefs.getBool('isPureBlack') ?? true;
    _showStatusBar = _prefs.getBool('showStatusBar') ?? true;
    _applyStatusBar();
    
    _iso = _prefs.getInt('iso') ?? isoValues[2];
    _aperture = _prefs.getDouble('aperture') ?? apertureValues[6];
    _shutterSpeed = _prefs.getDouble('shutterSpeed') ?? shutterValues[10];
    
    String targetStr = _prefs.getString('target') ?? 'shutter';
    _target = CalculationTarget.values.firstWhere((e) => e.name == targetStr, orElse: () => CalculationTarget.shutter);
    
    String ndStr = _prefs.getString('ndFilter') ?? 'none';
    _ndFilter = NdFilter.values.firstWhere((e) => e.name == ndStr, orElse: () => NdFilter.none);

    int colorValue = _prefs.getInt('primaryColor') ?? const Color(0xFFFFB300).value;
    _primaryColor = Color(colorValue);

    _calibrationFactor = _prefs.getDouble('calibrationFactor') ?? 1.0;

    String fpsStr = _prefs.getString('fpsOption') ?? '';
    if (fpsStr.isNotEmpty) {
      _fpsOption = FpsOption.values.firstWhere((e) => e.name == fpsStr, orElse: () => FpsOption.fps24);
      _shutterSpeed = _fpsOption!.shutterSpeed;
      if (_target == CalculationTarget.shutter) _target = CalculationTarget.iso;
    }

    _isInitialized = true;
    notifyListeners();
    
    _initSensor();
  }

  void _initSensor() {
    try {
      _subscription?.cancel();
      _subscription = AmbientLight().ambientLightStream.listen((double luxValue) {
        if (!_isLocked) {
          _currentLux = luxValue;
          _lastUpdate = DateTime.now();
          _recalculate();
          notifyListeners();
        }
      }, onError: (Object error) {
        _errorMessage = 'Sensor error: $error';
        notifyListeners();
      });
      _isListening = true;
      
      // Check if sensor is actually available
      AmbientLight().currentAmbientLight().then((lux) {
        if (lux == null) {
          _hasSensor = false;
          _errorMessage = 'No light sensor detected on this device.';
          notifyListeners();
        }
      });
    } catch (e) {
      _errorMessage = 'Could not initialize light sensor: $e';
      notifyListeners();
    }
  }

  void reinitializeSensor() {
    _errorMessage = '';
    _initSensor();
    notifyListeners();
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
    // Prevent switching to shutter target if FPS lock is active
    if (_fpsOption != null && newTarget == CalculationTarget.shutter) {
      return;
    }
    
    if (_target != newTarget) {
      _target = newTarget;
      _prefs.setString('target', newTarget.name);
      _triggerHaptic();
      _recalculate();
      notifyListeners();
    }
  }

  void setIso(int newIso) {
    if (_iso != newIso) {
      _iso = newIso;
      _prefs.setInt('iso', newIso);
      _triggerHaptic();
      if (_target == CalculationTarget.iso) {
        setTarget(CalculationTarget.shutter);
      }
      _recalculate();
    }
    notifyListeners();
  }

  void setAperture(double newAperture) {
    if (_aperture != newAperture) {
      _aperture = newAperture;
      _prefs.setDouble('aperture', newAperture);
      _triggerHaptic();
      if (_target == CalculationTarget.aperture) {
        setTarget(CalculationTarget.shutter);
      }
      _recalculate();
    }
    notifyListeners();
  }

  void setShutterSpeed(double newShutter) {
    if (_fpsOption != null) return; // Locked by video mode
    if (_shutterSpeed != newShutter) {
      _shutterSpeed = newShutter;
      _prefs.setDouble('shutterSpeed', newShutter);
      _triggerHaptic();
      if (_target == CalculationTarget.shutter) {
        setTarget(CalculationTarget.iso);
      }
      _recalculate();
    }
    notifyListeners();
  }

  void setNdFilter(NdFilter filter) {
    if (_ndFilter != filter) {
      _ndFilter = filter;
      _prefs.setString('ndFilter', filter.name);
      _triggerHaptic();
      _recalculate();
    }
    notifyListeners();
  }

  void setFpsOption(FpsOption? option) {
    if (_fpsOption != option) {
      _fpsOption = option;
      _prefs.setString('fpsOption', option?.name ?? '');
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
          _shutterSpeed = ExposureCalculator.calculateShutterSpeed(effectiveLux, _aperture, _iso, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        } else {
          // If FPS is locked but target is shutter (rare edge case), fallback to calculating ISO
          _target = CalculationTarget.iso;
          _iso = ExposureCalculator.calculateIso(effectiveLux, _aperture, _shutterSpeed, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        }
        break;
      case CalculationTarget.aperture:
        _aperture = ExposureCalculator.calculateAperture(effectiveLux, _shutterSpeed, _iso, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        break;
      case CalculationTarget.iso:
        _iso = ExposureCalculator.calculateIso(effectiveLux, _aperture, _shutterSpeed, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        break;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
