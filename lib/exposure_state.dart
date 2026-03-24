import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ambient_light/ambient_light.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exposure_calculator.dart';
import 'film_database.dart';

class ExposureState extends ChangeNotifier with WidgetsBindingObserver {
  StreamSubscription<double>? _subscription;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _batteryTimer;
  bool _hasSensor = true;
  bool get hasSensor => _hasSensor;
  String? _sensorName;
  String? get sensorName => _sensorName;
  
  DateTime? _lastUpdate;
  DateTime? get lastUpdate => _lastUpdate;
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  bool _hasShownSensorAlert = false;
  bool get hasShownSensorAlert => _hasShownSensorAlert;

  final Battery _battery = Battery();
  int _batteryLevel = 0;
  int get batteryLevel => _batteryLevel;
  BatteryState _currentBatteryState = BatteryState.unknown;
  BatteryState get currentBatteryState => _currentBatteryState;

  void markSensorAlertShown() {
    _hasShownSensorAlert = true;
    notifyListeners();
  }

  double _currentLux = 0.0;
  double get currentLux => _currentLux;

  FilmStock? _selectedFilm;
  FilmStock? get selectedFilm => _selectedFilm;

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

  // Standard EV recalibrated for film overexposure and manual compensation
  double get ev {
    double baseEv = ExposureCalculator.calculateEv(effectiveLux, ndFilter: _ndFilter);
    baseEv -= _exposureCompensation;
    if (_selectedFilm != null) {
      baseEv -= _selectedFilm!.recommendedOverexposure;
    }
    return baseEv;
  }

  double _exposureCompensation = 0.0;
  double get exposureCompensation => _exposureCompensation;

  void setExposureCompensation(double value) {
    if (_exposureCompensation != value) {
      _exposureCompensation = value;
      _prefs.setDouble('exposureCompensation', value);
      _triggerHaptic();
      _recalculate();
      notifyListeners();
    }
  }

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

  bool _useHalfSteps = false;
  bool get useHalfSteps => _useHalfSteps;

  bool _isPureBlack = true;
  bool get isPureBlack => _isPureBlack;

  Color _primaryColor = const Color(0xFFFFB300); // Default Amber
  Color get primaryColor => _primaryColor;

  bool _hideStatusBar = false;
  bool get hideStatusBar => _hideStatusBar;

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

  void togglePureBlack() {
    _isPureBlack = !_isPureBlack;
    _prefs.setBool('isPureBlack', _isPureBlack);
    _triggerHaptic();
    notifyListeners();
  }

  void toggleStatusBar() {
    _hideStatusBar = !_hideStatusBar;
    _prefs.setBool('hideStatusBar', _hideStatusBar);
    _applyStatusBar();
    _triggerHaptic();
    notifyListeners();
  }

  void _applyStatusBar() {
    if (_hideStatusBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    }
  }

  void resetDefaults() {
    _iso = isoValues[2]; // 160
    _aperture = apertureValues[6]; // f/2.8
    _shutterSpeed = shutterValues[10]; // 1/30
    _exposureCompensation = 0.0;
    _prefs.setInt('iso', _iso);
    _prefs.setDouble('aperture', _aperture);
    _prefs.setDouble('shutterSpeed', _shutterSpeed);
    _prefs.setDouble('exposureCompensation', _exposureCompensation);
    _hideStatusBar = false;
    _prefs.setBool('hideStatusBar', false);
    _applyStatusBar();
    _triggerHaptic(light: true);
    _recalculate();
    notifyListeners();
  }

  /// Wipes every saved preference and restarts the Android Activity.
  Future<void> resetAndRestart() async {
    await _prefs.clear();
    const platform = MethodChannel('com.arWRKS.lelemeter/sensor');
    try {
      await platform.invokeMethod('restartApp');
    } catch (e) {
      // Fallback if native restart fails - at least apply in-memory defaults
      debugPrint('Could not restart app natively: $e');
      resetDefaults();
    }
  }


  // Removed duplicates

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

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    _prefs.setInt('primaryColor', color.value);
    _triggerHaptic();
    notifyListeners();
  }

  void setCalibrationFactor(double factor) {
    _calibrationFactor = factor.clamp(0.1, 5.0);
    _prefs.setDouble('calibrationFactor', _calibrationFactor);
    _triggerHaptic(light: true);
    _recalculate();
    notifyListeners();
  }

  void resetCalibration() {
    setCalibrationFactor(1.0);
    _triggerHaptic();
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed, reinitializing sensor...');
      _initSensor();
      _initBattery();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('App backgrounded, stopping sensor...');
      _subscription?.cancel();
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> _initPrefsAndSensor() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load saved settings
    _themeMode = (_prefs.getBool('isDarkMode') ?? true) ? ThemeMode.dark : ThemeMode.light;
    _hapticsEnabled = _prefs.getBool('hapticsEnabled') ?? true;
    _useHalfSteps = _prefs.getBool('useHalfSteps') ?? false;
    _isPureBlack = _prefs.getBool('isPureBlack') ?? true;
    _hideStatusBar = _prefs.getBool('hideStatusBar') ?? false;
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
    _exposureCompensation = _prefs.getDouble('exposureCompensation') ?? 0.0;

    String filmName = _prefs.getString('selectedFilm') ?? '';
    if (filmName.isNotEmpty) {
      try {
        _selectedFilm = FilmDatabase.stocks.firstWhere((f) => f.name == filmName);
      } catch (_) {
        _selectedFilm = null;
      }
    }

    String fpsStr = _prefs.getString('fpsOption') ?? '';
    if (fpsStr.isNotEmpty) {
      _fpsOption = FpsOption.values.firstWhere((e) => e.name == fpsStr, orElse: () => FpsOption.fps24);
      _shutterSpeed = _fpsOption!.shutterSpeed;
      if (_target == CalculationTarget.shutter) _target = CalculationTarget.iso;
    }

    _isInitialized = true;
    notifyListeners();
    
    _initSensor();
    _initBattery();
  }

  Future<void> _initBattery() async {
    // Cancel any existing subscription/timer before reinit
    _batteryStateSubscription?.cancel();
    _batteryTimer?.cancel();

    // Initial read
    try {
      _batteryLevel = await _battery.batteryLevel;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not get battery level: $e');
    }

    // Listen for charging state changes (plugged in / unplugged)
    // and refresh the level immediately when that happens
    _batteryStateSubscription =
        _battery.onBatteryStateChanged.listen((BatteryState state) async {
      _currentBatteryState = state;
      try {
        _batteryLevel = await _battery.batteryLevel;
        notifyListeners();
      } catch (e) {
        debugPrint('Battery state update error: $e');
      }
    });

    // Poll every 60 seconds so the % stays fresh even with no state change
    _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        _batteryLevel = await _battery.batteryLevel;
        notifyListeners();
      } catch (e) {
        debugPrint('Battery poll error: $e');
      }
    });
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
          _sensorName = "SIMULATED / NOT DETECTED";
          notifyListeners();
        } else {
          _fetchSensorName();
        }
      });
    } catch (e) {
      _errorMessage = 'Could not initialize light sensor: $e';
      notifyListeners();
    }
  }

  Future<void> _fetchSensorName() async {
    const platform = MethodChannel('com.arWRKS.lelemeter/sensor');
    try {
      final String? name = await platform.invokeMethod('getSensorName');
      _sensorName = name;
      notifyListeners();
    } on MissingPluginException catch (_) {
      debugPrint("MissingPluginException: Rebuild required to pick up native changes.");
      _sensorName = "GENERIC (REBUILD REQUIRED)";
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint("Failed to get sensor name: '${e.message}'.");
      _sensorName = "GENERIC SENSOR";
      notifyListeners();
    }
  }

  void reinitializeSensor() {
    _errorMessage = '';
    _initSensor();
    notifyListeners();
  }

  void resetSensor() {
    _triggerHaptic();
    _errorMessage = '';
    _currentLux = 0.0;
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
      _selectedFilm = null; // Reset selected film if ISO is manually changed
      _prefs.remove('selectedFilm');
      _triggerHaptic();
      if (_target == CalculationTarget.iso) {
        setTarget(CalculationTarget.shutter);
      }
      _recalculate();
    }
    notifyListeners();
  }

  void selectFilm(FilmStock? film) {
    _selectedFilm = film;
    if (film != null) {
      _prefs.setString('selectedFilm', film.name);
      
      // If ISO was the calculation target, switch to shutter
      if (_target == CalculationTarget.iso) {
        _target = CalculationTarget.shutter;
        _prefs.setString('target', 'shutter');
      }

      // Set ISO to film's box speed (LOCKED)
      _iso = ExposureCalculator.findClosest(film.iso.toDouble(), isoValues).toInt();
      _prefs.setInt('iso', _iso);
    } else {
      _prefs.remove('selectedFilm');
    }
    _triggerHaptic();
    _recalculate();
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
    double lux = effectiveLux;
    // Total exposure offset in stops (Manual EV Comp + Film Overexposure)
    double totalOffset = _exposureCompensation;
    if (_selectedFilm != null) {
      totalOffset += _selectedFilm!.recommendedOverexposure;
    }

    // Apply total offset to lux BEFORE calculations
    // +1 stop extra exposure = telling the meter it's darker (lux / 2)
    if (totalOffset != 0) {
      double factor = math.pow(2.0, -totalOffset).toDouble();
      lux *= factor;
    }

    if (lux <= 0) return;

    switch (_target) {
      case CalculationTarget.shutter:
        if (_fpsOption == null) {
          _shutterSpeed = ExposureCalculator.calculateShutterSpeed(lux, _aperture, _iso, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        } else {
          // If FPS is locked but target is shutter (rare edge case), fallback to calculating ISO
          _target = CalculationTarget.iso;
          _iso = ExposureCalculator.calculateIso(lux, _aperture, _shutterSpeed, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        }
        break;
      case CalculationTarget.aperture:
        _aperture = ExposureCalculator.calculateAperture(lux, _shutterSpeed, _iso, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        break;
      case CalculationTarget.iso:
        _iso = ExposureCalculator.calculateIso(lux, _aperture, _shutterSpeed, ndFilter: _ndFilter, halfSteps: _useHalfSteps);
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _batteryStateSubscription?.cancel();
    _batteryTimer?.cancel();
    super.dispose();
  }
}
