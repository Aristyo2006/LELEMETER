import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'exposure_state.dart';
import 'exposure_calculator.dart';
import 'film_database.dart';
import 'logbook/log_creator_screen.dart';

// LCD fallback (used as default; actual color comes from state.lcdColor)
const _lcdGreenDefault = Color(0xFF8EFF71);
const _lcdAmber = Color(0xFFFBBC00);
const _lcdBg    = Color(0xFF060E06);

class AnalogViewfinderScreen extends StatefulWidget {
  const AnalogViewfinderScreen({super.key});
  @override
  State<AnalogViewfinderScreen> createState() => _AnalogViewfinderScreenState();
}

class _AnalogViewfinderScreenState extends State<AnalogViewfinderScreen> with WidgetsBindingObserver {
  MethodChannel? _methodChannel;
  StreamSubscription? _eventSubscription;

  bool _isAELocked = false;
  final ValueNotifier<HistogramData> _histogramNotifier = ValueNotifier(
    HistogramData(List.filled(256, 0), List.filled(256, 0), List.filled(256, 0), 1),
  );

  Offset? _meterPoint;
  double _currentZoom = 1.0;
  double _lastScaleZoom = 1.0;
  bool _showHistogram = true;
  bool _bwMode = false;
  bool _filmSimEnabled = true;
  bool _isSpotMetering = true;
  // ignore: prefer_final_fields
  bool _livePreview = true;
  late ExposureState _exposureState;
  double _lastSentEvComp = 0.0;
  List<double>? _customLutMatrix;
  String? _lastLoadedFilm;

  // ── Logbook capture ──
  bool _capturing = false; // shows overlay while native capture + film-sim bake run

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _exposureState.setUsingCameraSensor(true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exposureState = Provider.of<ExposureState>(context, listen: false);
  }

  // Sync camera state on ExposureState changes (avoids postFrameCallback in build)
  void _syncCameraState(ExposureState state) {
    if (_methodChannel == null) return;
    final isBWFilm = state.selectedFilm?.type == FilmType.blackWhite;
    if (isBWFilm != _bwMode) {
      _bwMode = isBWFilm;
      _methodChannel?.invokeMethod('setBlackAndWhite', {'enabled': isBWFilm});
    }
    if ((state.exposureCompensation - _lastSentEvComp).abs() > 0.05) {
      _syncEvComp(state.exposureCompensation);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _exposureState.setUsingCameraSensor(false);
    Future.delayed(const Duration(milliseconds: 300), _exposureState.reinitializeSensor);
    _histogramNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _methodChannel?.invokeMethod('resumeCamera');
    }
  }

  void _resetFocus() {
    _methodChannel?.invokeMethod('setMeteringPoint', {'x': -1.0, 'y': -1.0});
    setState(() {
      _meterPoint = null;
      _isSpotMetering = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _onPlatformViewCreated(int id) {
    _methodChannel = MethodChannel('com.arWRKS.lelemeter/camera_methods_$id');
    final eventChannel = EventChannel('com.arWRKS.lelemeter/camera_events_$id');

    _eventSubscription = eventChannel.receiveBroadcastStream().listen((data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data);

      _histogramNotifier.value = HistogramData(
        List<int>.from(map['rHist']),
        List<int>.from(map['gHist']),
        List<int>.from(map['bHist']),
        map['maxVal'] as int,
      );

      final bool isLocked = map['isLocked'] as bool;
      if (isLocked) {
        _exposureState.updateExposureFromCamera(map['calculatedEV'] as double);
      } else {
        final shutterSec = (map['shutterNs'] as int) / 1e9;
        _exposureState.updateExposureFromCamera(
          ExposureCalculator.calculateSettingsEv(1.8, shutterSec, map['iso'] as int));
      }
    });
  }

  void _toggleBW() {
    setState(() => _bwMode = !_bwMode);
    _methodChannel?.invokeMethod('setBlackAndWhite', {'enabled': _bwMode});
    HapticFeedback.lightImpact();
  }

  // void _toggleLivePreview() {
  //   setState(() => _livePreview = !_livePreview);
  //   _methodChannel?.invokeMethod('setLivePreview', {'enabled': _livePreview});
  //   HapticFeedback.lightImpact();
  // }

  void _syncEvComp(double evComp) {
    // Camera2 AE comp steps ≈ 1/6 EV each on most phones
    final steps = (evComp * 6).round();
    _methodChannel?.invokeMethod('setEvComp', {'steps': steps});
    _lastSentEvComp = evComp;
  }

  void _toggleLock() {
    final ev = _exposureState.ev;
    if (_isAELocked) {
      _methodChannel?.invokeMethod('unlockAE');
      setState(() => _isAELocked = false);
    } else {
      _methodChannel?.invokeMethod('lockAE', {'baseEV': ev});
      setState(() => _isAELocked = true);
    }
    HapticFeedback.mediumImpact();
  }

  /// Capture a still frame for the Logbook. Reads the *current* exposure
  /// settings as an immutable snapshot (decoupled from live state), then opens
  /// the LogCreator. Does not modify any metering/EV state.
  Future<void> _captureForLog() async {
    if (_capturing || _methodChannel == null) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();

    try {
      // Snapshot the live settings BEFORE navigation so the entry is stable.
      final snap = ExposureSnapshot(
        shutterSpeed: _exposureState.shutterSpeed,
        aperture: _exposureState.aperture,
        iso: _exposureState.iso,
        ev: _exposureState.ev,
        exposureCompensation: _exposureState.exposureCompensation,
        filmName: _exposureState.selectedFilm?.name,
      );

      final path = await _methodChannel!.invokeMethod<String>('capturePhoto');
      if (path == null || path.isEmpty) {
        _captureError('Capture failed.');
        return;
      }
      if (!mounted) return;

      // Brief shutter flash for tactile feedback, then open the creator.
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LogCreatorScreen(
            imagePath: path,
            snapshot: snap,
            film: _exposureState.selectedFilm,
            customLutMatrix: _customLutMatrix,
          ),
        ),
      );
    } on PlatformException catch (e) {
      _captureError('Capture failed: ${e.message ?? e.code}');
    } catch (e) {
      _captureError('Capture failed: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _captureError(String msg) {
    if (!mounted) return;
    setState(() => _capturing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }


  void _setZoom(double z) {
    final clamped = z.clamp(1.0, 5.0);
    if ((clamped - _currentZoom).abs() < 0.001) return;
    setState(() => _currentZoom = clamped);
    _methodChannel?.invokeMethod('setZoom', {'zoom': clamped});
  }

  void _tapToMeter(TapDownDetails details, Size screenSize) {
    if (_methodChannel == null) return;
    final dx = details.localPosition.dx / screenSize.width;
    final dy = details.localPosition.dy / screenSize.height;
    _methodChannel!.invokeMethod('setMeteringPoint', {'x': dx, 'y': dy});
    HapticFeedback.lightImpact();
    setState(() {
      _meterPoint = Offset(dx, dy);
      _isSpotMetering = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExposureState>();
    final screenSize = MediaQuery.of(context).size;

    // Calculate 3:4 preview rect inside the screen (BoxFit.contain logic)
    const double aspect = 3 / 4;
    double pw, ph, pt, pl;
    if (screenSize.aspectRatio > aspect) {
      ph = screenSize.height;
      pw = ph * aspect;
      pt = 0;
      pl = (screenSize.width - pw) / 2;
    } else {
      pw = screenSize.width;
      ph = pw / aspect;
      pl = 0;
      // Push viewfinder up (30% padding top instead of 50%)
      pt = (screenSize.height - ph) * 0.3;
    }
    final previewRect = Rect.fromLTWH(pl, pt, pw, ph);

    // Sync camera state on changes (no postFrameCallback needed)
    _syncCameraState(state);

    // Used in the top bar for B&W toggle visibility
    final isBWFilm = state.selectedFilm?.type == FilmType.blackWhite;

    // Load LUT Matrix if film changed
    if (state.selectedFilm != null && state.selectedFilm!.name != _lastLoadedFilm) {
      _lastLoadedFilm = state.selectedFilm!.name;
      _loadLutMatrix(state.selectedFilm!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Camera + HUD Layer (Filtered together) ─────────────────────
        Positioned.fromRect(
          rect: previewRect,
          child: ClipRect(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _tapToMeter(d, previewRect.size),
              onScaleStart: (_) => _lastScaleZoom = _currentZoom,
              onScaleUpdate: (d) {
                if (d.pointerCount < 2) return;
                _setZoom(_lastScaleZoom * d.scale);
              },
              child: Stack(children: [
                // Camera Feed
                Positioned.fill(
                  child: _livePreview
                    ? ColorFiltered(
                        colorFilter: _filmSimEnabled 
                            ? (_customLutMatrix != null ? ColorFilter.matrix(_customLutMatrix!) : _getFilmMatrix(state.selectedFilm)) 
                            : const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]),
                        child: AndroidView(
                          viewType: 'NativeCameraView',
                          onPlatformViewCreated: _onPlatformViewCreated,
                          creationParamsCodec: const StandardMessageCodec(),
                        ),
                      )
                    : Container(color: const Color(0xFF0A0A0A),
                        child: const Center(child: Icon(Icons.videocam_off, color: Colors.white12, size: 48))),
                ),

                  // HUD Elements (Corners, center spot, etc.)
                  ..._corners(),

                  // Center spot circle
                  Center(
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Container(
                        width: 4, height: 4,
                        decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle),
                      )),
                    ),
                  ),

                  // Tap metering indicator
                  if (_meterPoint != null)
                    Positioned(
                      left: _meterPoint!.dx * pw - 22,
                      top:  _meterPoint!.dy * ph - 22,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          border: Border.all(color: _lcdGreenDefault, width: 1.5),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _lcdGreenDefault.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: Center(child: Container(
                          width: 4, height: 4,
                          decoration: const BoxDecoration(color: _lcdGreenDefault, shape: BoxShape.circle),
                        )),
                      ),
                    ),
                ]),
              ),
            ),
          ),

        // ── Histogram ─────────────────────────────────────────────────
        if (_showHistogram)
          Positioned(
            top: pt + 12, left: pl + 12, width: 130, height: 60,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _lcdGreenDefault.withValues(alpha: 0.2), width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ValueListenableBuilder<HistogramData>(
                    valueListenable: _histogramNotifier,
                    builder: (context, data, _) {
                      return CustomPaint(
                        painter: HistogramPainter(data.r, data.g, data.b, data.maxVal),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

        // ── Zoom dial (drag up/down to zoom) ───────────────────────────
        Positioned(
          right: pl + 8, bottom: (screenSize.height - (pt + ph)) + 20,
          child: RepaintBoundary(
            child: _ZoomDial(
              zoom: _currentZoom,
              onDelta: (dz) => _setZoom(_currentZoom + dz),
            ),
          ),
        ),

        // ── Top bar ───────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: RepaintBoundary(
            child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.black87,
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (state.selectedFilm != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _lcdAmber, borderRadius: BorderRadius.circular(4)),
                    child: Row(children: [
                      const Icon(Icons.camera_roll_outlined, size: 10, color: Colors.black),
                      const SizedBox(width: 4),
                      Text(state.selectedFilm!.name.toUpperCase(),
                        style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 9,
                          fontWeight: FontWeight.bold, color: Colors.black)),
                      if (_bwMode) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2)),
                          child: const Text("B/W", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ]),
                  ),
                if (state.selectedFilm != null) ...[
                  _topBtn(icon: Icons.movie_filter, color: _filmSimEnabled ? Colors.white : Colors.white38,
                    label: 'SIM', active: _filmSimEnabled, onTap: () => setState(() => _filmSimEnabled = !_filmSimEnabled)),
                  const SizedBox(width: 2),
                ],
                _topBtn(icon: _isAELocked ? Icons.lock : Icons.lock_open,
                  color: _isAELocked ? _lcdAmber : Colors.white54,
                  label: 'AE-L', active: _isAELocked, onTap: _toggleLock),
                const SizedBox(width: 2),
                _topBtn(icon: _isSpotMetering ? Icons.filter_center_focus : Icons.filter_none,
                  color: Colors.white54, label: _isSpotMetering ? 'SPOT' : 'MATR', 
                  active: _isSpotMetering, onTap: () {
                    if (_isSpotMetering) {
                      _resetFocus();
                    } else {
                      _tapToMeter(TapDownDetails(localPosition: Offset(pw/2, ph/2)), previewRect.size);
                    }
                  }),
                const SizedBox(width: 2),
                _topBtn(icon: _showHistogram ? Icons.bar_chart : Icons.bar_chart_outlined,
                  color: Colors.white54, label: 'HIST', active: _showHistogram,
                  onTap: () => setState(() => _showHistogram = !_showHistogram)),
                if (isBWFilm) ...[    // B&W toggle only for B&W film
                  const SizedBox(width: 2),
                  _topBtn(icon: Icons.tonality, color: _bwMode ? Colors.white : Colors.white38,
                    label: 'B&W', active: _bwMode, onTap: _toggleBW),
                ],
              ]),
            ),
          ),
        ),
      ),

        // ── EV Bar (left side, vertical, small) ──
        Positioned(
          left: pl, top: pt + 40, bottom: (screenSize.height - (pt + ph)) + 40,
          child: RepaintBoundary(
            child: _evSideBar(state, state.lcdColor),
          ),
        ),

        // ── Bottom HUD ─────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(top: false, child: RepaintBoundary(child: _buildHUD(state))),
        ),

        // ── Shutter (Logbook capture) ───────────────────────────────────
        Positioned(
          bottom: screenSize.height * 0.30,
          left: 0,
          right: 0,
          child: Center(child: _shutterButton()),
        ),

        // ── Capture overlay (flash + spinner) ───────────────────────────
        if (_capturing) Positioned.fill(child: _captureOverlay()),
      ]),
    );
  }

  // ── Builders ────────────────────────────────────────────────────────

  Widget _topBtn({required IconData icon, required Color color, required String label,
      required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color.withValues(alpha: 0.5) : Colors.transparent, width: 0.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontFamily: 'VT323', fontSize: 9, color: color, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _evSideBar(ExposureState state, Color lcdC) {
    // p=0 means +3 EV (top), p=1 means -3 EV (bottom)
    final double p = 1.0 - ((state.exposureCompensation.clamp(-3.0, 3.0) + 3.0) / 6.0);
    final c = _isAELocked ? _lcdAmber : lcdC;
    return Container(
      width: 22,
      decoration: BoxDecoration(
        color: _lcdBg.withValues(alpha: 0.90),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
        border: Border.all(color: c.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text('EV', style: TextStyle(fontFamily: 'VT323', fontSize: 7, color: c.withValues(alpha: 0.5))),
        ),
        Expanded(
          child: LayoutBuilder(builder: (_, cs) {
            final h = cs.maxHeight - 12; // 6px padding top/bottom
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Stack(children: [
                // Center track
                Center(child: Container(
                  width: 1, height: h,
                  color: c.withValues(alpha: 0.12))),
                // 7 tick marks with label
                ...List.generate(7, (i) {
                  final yFrac = i / 6.0;
                  final isCenter = i == 3;
                  return Positioned(
                    top: (yFrac * h).clamp(0, h),
                    left: 0, right: 0,
                    child: Center(
                      child: Container(width: isCenter ? 7 : 4, height: 1.2,
                        color: c.withValues(alpha: isCenter ? 0.7 : 0.4)),
                    ),
                  );
                }),
                // Small label overlay (moved to avoid clipping)
                ...List.generate(7, (i) {
                  final yFrac = i / 6.0;
                  final label = ['+3','+2','+1','0','-1','-2','-3'][i];
                  return Positioned(
                    top: (yFrac * h) - 4,
                    right: 2,
                    child: Text(label, style: TextStyle(fontFamily: 'VT323', fontSize: 6, color: c.withValues(alpha: 0.4))),
                  );
                }),
                // Animated needle (small horizontal bar)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 80),
                  top: (p * h - 1).clamp(0, h - 2),
                  left: 3, right: 7, // Thinner needle
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [BoxShadow(color: c, blurRadius: 4)],
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(height: 3),
      ]),
    );
  }

  List<Widget> _corners() {
    const c = Colors.white24;
    const len = 22.0;
    const t = 1.5;
    const p = 18.0;
    return [
      Positioned(top: p, left: p, child: SizedBox(width: len, height: len,
        child: CustomPaint(painter: _CornerPainter(Alignment.topLeft, c, t)))),
      Positioned(top: p, right: p, child: SizedBox(width: len, height: len,
        child: CustomPaint(painter: _CornerPainter(Alignment.topRight, c, t)))),
      Positioned(bottom: 260, left: p, child: SizedBox(width: len, height: len,
        child: CustomPaint(painter: _CornerPainter(Alignment.bottomLeft, c, t)))),
      Positioned(bottom: 260, right: p, child: SizedBox(width: len, height: len,
        child: CustomPaint(painter: _CornerPainter(Alignment.bottomRight, c, t)))),
    ];
  }


  Widget _buildHUD(ExposureState state) {
    final apertLocked = state.target == CalculationTarget.aperture;
    final isoLocked   = state.target == CalculationTarget.iso || state.selectedFilm != null;
    final shutLocked  = state.target == CalculationTarget.shutter || state.fpsOption != null;

    return Container(
      color: Colors.black,
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // LCD strip — Pure T / F/ / ISO / EV
        Container(
          color: _lcdBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _lcdCell('T',   ExposureCalculator.formatShutterSpeed(state.shutterSpeed), state.lcdColor),
            _divider(state.lcdColor),
            _lcdCell('F/', state.aperture.toStringAsFixed(1), state.lcdColor),
            _divider(state.lcdColor),
            _lcdCell('ISO', '${state.iso}', state.lcdColor),
            _divider(state.lcdColor),
            _lcdCell('EV',  state.ev.toStringAsFixed(1),
              _isAELocked ? _lcdAmber : state.lcdColor, glow: true),
          ]),
        ),

        // Control blocks
        Container(
          color: const Color(0xFF0A0A0A),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: _ctrl('F/ APERTURE', state.aperture.toStringAsFixed(1), Colors.white, apertLocked,
                m: apertLocked ? null : () => _step(ExposureCalculator.apertureValues, state.aperture, -1, state.setAperture),
                p: apertLocked ? null : () => _step(ExposureCalculator.apertureValues, state.aperture,  1, state.setAperture))),
              const SizedBox(width: 8),
              Expanded(child: _ctrl('ISO', '${state.iso}', Colors.white, isoLocked,
                m: isoLocked ? null : () => _stepInt(ExposureCalculator.isoValues, state.iso, -1, state.setIso),
                p: isoLocked ? null : () => _stepInt(ExposureCalculator.isoValues, state.iso,  1, state.setIso))),
            ]),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(child: _ctrl('SEC SHUTTER', ExposureCalculator.formatShutterSpeed(state.shutterSpeed), const Color(0xFFEE7D77), shutLocked,
                m: shutLocked ? null : () => _step(ExposureCalculator.shutterValues, state.shutterSpeed, -1, state.setShutterSpeed),
                p: shutLocked ? null : () => _step(ExposureCalculator.shutterValues, state.shutterSpeed,  1, state.setShutterSpeed))),
              const SizedBox(width: 8),
              // EV Comp block
              Expanded(child: _ctrl('EV COMP',
                '${state.exposureCompensation >= 0 ? '+' : ''}${state.exposureCompensation.toStringAsFixed(1)}',
                state.exposureCompensation != 0 ? state.lcdColor : Colors.white, false,
                m: () => state.setExposureCompensation(state.exposureCompensation - 0.3),
                p: () => state.setExposureCompensation(state.exposureCompensation + 0.3))),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Shutter button (Logbook capture) ────────────────────────────────
  Widget _shutterButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _capturing ? null : _captureForLog,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white24, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 12),
          ],
        ),
        child: _capturing
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                ),
              )
            : const Icon(Icons.camera, color: Colors.black, size: 24),
      ),
    );
  }

  /// Full-screen white flash + spinner while capture runs.
  Widget _captureOverlay() {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          color: Colors.white.withValues(alpha: 0.15),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _lcdCell(String label, String value, Color lcdC, {bool glow = true}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontFamily: 'VT323', fontSize: 9,
        color: lcdC.withValues(alpha: 0.55), letterSpacing: 1)),
      Text(value, style: TextStyle(
        fontFamily: 'DSEG14Classic', fontStyle: FontStyle.italic,
        fontSize: 20, color: lcdC, letterSpacing: 1,
        shadows: glow ? [Shadow(color: lcdC, blurRadius: 12), Shadow(color: lcdC, blurRadius: 6)] : null,
      )),
    ]);
  }

  Widget _divider(Color lcdC) =>    Container(width: 1, height: 30, color: lcdC.withValues(alpha: 0.15));

  Widget _ctrl(String label, String value, Color vc, bool locked,
      {VoidCallback? m, VoidCallback? p}) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: locked ? const Color(0xFF141414) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: locked ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
            child: Row(children: [
              Text(label, style: const TextStyle(fontFamily: 'VT323', fontSize: 9,
                color: Color(0xFF9D9E9E), letterSpacing: 1)),
              if (locked) ...[const SizedBox(width: 4), const Icon(Icons.lock, size: 7, color: _lcdAmber)],
            ]),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: m != null ? () { HapticFeedback.lightImpact(); m(); } : null,
              child: Container(
                width: 48, height: 36,
                alignment: Alignment.center,
                child: Icon(Icons.remove, size: 18,
                  color: m != null ? Colors.white70 : Colors.white12),
              ),
            ),
            Text(value, style: TextStyle(
              fontFamily: 'DSEG14Classic', fontStyle: FontStyle.italic, fontSize: 16,
              color: locked ? vc.withValues(alpha: 0.35) : vc,
              shadows: locked ? null : [Shadow(color: vc.withValues(alpha: 0.5), blurRadius: 8)],
            )),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: p != null ? () { HapticFeedback.lightImpact(); p(); } : null,
              child: Container(
                width: 48, height: 36,
                alignment: Alignment.center,
                child: Icon(Icons.add, size: 18,
                  color: p != null ? Colors.white70 : Colors.white12),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────
  void _step<T extends num>(List<T> list, T cur, int d, void Function(T) set) {
    final idx = list.indexOf(cur);
    final next = (idx + d).clamp(0, list.length - 1);
    set(list[next]);
  }

  void _stepInt(List<int> list, int cur, int d, void Function(int) set) =>
    _step(list, cur, d, set);

  Future<void> _loadLutMatrix(FilmStock film) async {
    final name = film.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    final folders = ['bw','colorslide','fujixtransiii','instant_consumer','instant_pro','negative_color','negative_new','negative_old','print',''];
    
    for (final f in folders) {
      final path = "assets/luts/${f.isEmpty ? '' : '$f/'}$name.cube";
      try {
        final data = await rootBundle.loadString(path);
        final matrix = _parseCubeToMatrix(data);
        if (matrix != null) {
          setState(() => _customLutMatrix = matrix);
          // Send to Native OGL
          await _methodChannel?.invokeMethod('setLutPath', {'path': path});
          return;
        }
      } catch (_) {} 
    }
    setState(() => _customLutMatrix = null);
  }

  List<double>? _parseCubeToMatrix(String cubeData) {
    final lines = cubeData.split('\n');
    int size = 0;
    List<List<double>> points = [];
    
    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('LUT_3D_SIZE')) {
        size = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
        continue;
      }
      if (line.isEmpty || line.startsWith('#') || RegExp(r'^[a-zA-Z]').hasMatch(line)) continue;
      final parts = line.split(RegExp(r'\s+')).map(double.tryParse).toList();
      if (parts.length == 3 && parts[0] != null) {
        points.add([parts[0]!, parts[1]!, parts[2]!]);
      }
    }

    if (size < 2 || points.length < size * size * size) return null;

    final black = points[0];
    final red   = points[size - 1];
    final green = points[(size - 1) * size];
    final blue  = points[(size - 1) * size * size];

    return [
      (red[0] - black[0]), (green[0] - black[0]), (blue[0] - black[0]), 0.0, black[0] * 255,
      (red[1] - black[1]), (green[1] - black[1]), (blue[1] - black[1]), 0.0, black[1] * 255,
      (red[2] - black[2]), (green[2] - black[2]), (blue[2] - black[2]), 0.0, black[2] * 255,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
  }

  ColorFilter _getFilmMatrix(FilmStock? film) {
    if (film == null) return _identityMatrix();
    
    final name = film.name.toLowerCase();
    
    if (film.type == FilmType.blackWhite) {
      if (name.contains("tri-x")) {
        return const ColorFilter.matrix([
          0.3, 0.7, 0.1, 0, -20,
          0.3, 0.7, 0.1, 0, -20,
          0.3, 0.7, 0.1, 0, -20,
          0,   0,   0,   1, 0,
        ]);
      }
      return const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);
    }

    if (name.contains("portra")) {
      return const ColorFilter.matrix([
        1.1, 0.0, 0.0, 0, 5,
        0.0, 1.0, 0.0, 0, 2,
        0.0, 0.0, 0.95, 0, -2,
        0,   0,   0,   1, 0,
      ]);
    } else if (name.contains("gold")) {
      return const ColorFilter.matrix([
        1.2, 0.0, 0.0, 0, 10,
        0.0, 1.1, 0.0, 0, 5,
        0.0, 0.0, 0.8, 0, -10,
        0,   0,   0,   1, 0,
      ]);
    } else if (name.contains("ektar")) {
      return const ColorFilter.matrix([
        1.15, 0.05, 0.05, 0, 0,
        0.0,  1.15, 0.0,  0, 0,
        0.0,  0.0,  1.15, 0, 0,
        0,    0,    0,    1, 0,
      ]);
    } else if (name.contains("velvia")) {
      return const ColorFilter.matrix([
        1.0, 0.0, 0.0, 0, 0,
        0.1, 1.2, 0.0, 0, 5,
        0.0, 0.1, 1.2, 0, 5,
        0,   0,   0,   1, 0,
      ]);
    } else if (name.contains("cinestill") || name.contains("vision3")) {
      return const ColorFilter.matrix([
        1.0, 0.0, 0.0, 0, 0,
        0.0, 0.9, 0.2, 0, -5,
        0.1, 0.0, 1.2, 0, 10,
        0,   0,   0,   1, 0,
      ]);
    }

    if (film.brand == "Kodak") {
      return const ColorFilter.matrix([1.1, 0.05, 0, 0, 5, 0, 1.05, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0]);
    } else if (film.brand == "Fujifilm") {
      return const ColorFilter.matrix([0.95, 0, 0, 0, 0, 0, 1.1, 0.05, 0, 0, 0, 0.05, 1.1, 0, 0, 0, 0, 0, 1, 0]);
    }

    return _identityMatrix();
  }

  ColorFilter _identityMatrix() {
    return const ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }
}

// ── Zoom Dial ─────────────────────────────────────────────────────────────
class _ZoomDial extends StatelessWidget {
  final double zoom;
  final void Function(double delta) onDelta;
  const _ZoomDial({required this.zoom, required this.onDelta});

  @override
  Widget build(BuildContext context) {
    const sz = 68.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => onDelta(d.delta.dy * -0.025),
      onHorizontalDragUpdate: (d) => onDelta(d.delta.dx * 0.025),
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111111),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 10),
            BoxShadow(color: _lcdGreenDefault.withValues(alpha: 0.08), blurRadius: 16),
          ],
        ),
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: const Size(sz, sz), painter: _DialPainter(zoom)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(24 * zoom).toInt()}', style: const TextStyle(
              fontFamily: 'DSEG14Classic', fontStyle: FontStyle.italic,
              fontSize: 16, color: _lcdGreenDefault,
              shadows: [Shadow(color: _lcdGreenDefault, blurRadius: 10)],
            )),
            const Text('mm', style: TextStyle(fontFamily: 'VT323', fontSize: 9, color: Colors.white38)),
          ]),
        ]),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double zoom;
  _DialPainter(this.zoom);
  @override
  void paint(Canvas canvas, Size size) {
    final base  = Paint()..color = Colors.white24..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final active = Paint()..color = _lcdGreenDefault..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    const n = 24;
    final lit = ((zoom - 1.0) / 4.0 * n).round();
    for (int i = 0; i < n; i++) {
      final a  = (i / n) * math.pi * 2 - math.pi / 2;
      final p  = i < lit ? active : base;
      final l  = i < lit ? 7.0 : 4.0;
      canvas.drawLine(
        Offset(c.dx + (r - l) * math.cos(a), c.dy + (r - l) * math.sin(a)),
        Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a)),
        p,
      );
    }
  }
  @override
  bool shouldRepaint(_DialPainter o) => o.zoom != zoom;
}

// ── Corner Painter ────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Alignment corner;
  final Color color;
  final double thick;
  _CornerPainter(this.corner, this.color, this.thick);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = thick..style = PaintingStyle.stroke;
    final w = size.width; final h = size.height;
    if (corner == Alignment.topLeft) {
      canvas.drawLine(Offset.zero, Offset(w, 0), p);
      canvas.drawLine(Offset.zero, Offset(0, h), p);
    } else if (corner == Alignment.topRight) {
      canvas.drawLine(Offset.zero, Offset(w, 0), p);
      canvas.drawLine(Offset(w, 0), Offset(w, h), p);
    } else if (corner == Alignment.bottomLeft) {
      canvas.drawLine(Offset(0, h), Offset(w, h), p);
      canvas.drawLine(Offset(0, 0), Offset(0, h), p);
    } else {
      canvas.drawLine(Offset(0, h), Offset(w, h), p);
      canvas.drawLine(Offset(w, 0), Offset(w, h), p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── Histogram Painter ─────────────────────────────────────────────────────
class HistogramPainter extends CustomPainter {
  final List<int> r, g, b;
  final int maxVal;
  HistogramPainter(this.r, this.g, this.b, this.maxVal);
  @override
  void paint(Canvas canvas, Size size) {
    if (maxVal == 0) return;
    final pr = Paint()..color = Colors.red.withValues(alpha: 0.7)..strokeWidth = 1..style = PaintingStyle.stroke;
    final pg = Paint()..color = const Color(0xFF8EFF71).withValues(alpha: 0.7)..strokeWidth = 1..style = PaintingStyle.stroke;
    final pb = Paint()..color = Colors.blue.withValues(alpha: 0.7)..strokeWidth = 1..style = PaintingStyle.stroke;
    final step = size.width / 256;

    final pathR = Path();
    final pathG = Path();
    final pathB = Path();

    for (int i = 0; i < 256; i++) {
      final x = i * step;
      pathR.moveTo(x, size.height);
      pathR.lineTo(x, size.height - (r[i] / maxVal) * size.height);

      pathG.moveTo(x, size.height);
      pathG.lineTo(x, size.height - (g[i] / maxVal) * size.height);

      pathB.moveTo(x, size.height);
      pathB.lineTo(x, size.height - (b[i] / maxVal) * size.height);
    }

    canvas.drawPath(pathR, pr);
    canvas.drawPath(pathG, pg);
    canvas.drawPath(pathB, pb);
  }
  @override
  bool shouldRepaint(covariant HistogramPainter oldDelegate) =>
      oldDelegate.maxVal != maxVal || oldDelegate.r != r || oldDelegate.g != g || oldDelegate.b != b;
}

class HistogramData {
  final List<int> r;
  final List<int> g;
  final List<int> b;
  final int maxVal;
  HistogramData(this.r, this.g, this.b, this.maxVal);
}
