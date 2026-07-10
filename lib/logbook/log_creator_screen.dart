import 'dart:io';

import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../exposure_state.dart';
import '../film_database.dart';
import 'film_sim_bake.dart';
import 'logbook_cover_screen.dart';
import 'logbook_store.dart';
import 'logbook_theme.dart';
import 'developing_photo.dart';

/// The exposure data handed over from the viewfinder at capture time.
/// Snapshot — never references live state.
class ExposureSnapshot {
  final double shutterSpeed;
  final double aperture;
  final int iso;
  final double ev;
  final double exposureCompensation;
  final String? filmName;
  final int? focalLength;

  const ExposureSnapshot({
    required this.shutterSpeed,
    required this.aperture,
    required this.iso,
    required this.ev,
    required this.exposureCompensation,
    this.filmName,
    this.focalLength,
  });
}

/// Shown immediately after a successful capture in the viewfinder.
/// The image at [imagePath] is a temp JPEG produced natively.
class LogCreatorScreen extends StatefulWidget {
  final String imagePath;
  final ExposureSnapshot snapshot;
  final FilmStock? film;
  final List<double>? customLutMatrix;

  const LogCreatorScreen({
    super.key,
    required this.imagePath,
    required this.snapshot,
    this.film,
    this.customLutMatrix,
  });

  @override
  State<LogCreatorScreen> createState() => _LogCreatorScreenState();
}

class _LogCreatorScreenState extends State<LogCreatorScreen> {
  late final TextEditingController _rollCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  bool _hasColorFilm = false; // whether a film-sim look is available to bake
  bool _bake = true;
  bool _addLocation = false;
  bool _locating = false;
  bool _saving = false;
  String? _placeName;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    String? lastRoll;
    for (final e in LogbookStore.instance.entries) {
      if (e.roll != null && e.roll!.trim().isNotEmpty) {
        lastRoll = e.roll;
        break;
      }
    }
    _rollCtrl = TextEditingController(text: lastRoll ?? '');
    _titleCtrl = TextEditingController(text: widget.snapshot.filmName ?? '');
    _noteCtrl = TextEditingController();
    _hasColorFilm =
        filmSimMatrix(widget.film) != null || widget.customLutMatrix != null;
    _bake = _hasColorFilm;
  }

  @override
  void dispose() {
    _rollCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLocation(bool? value) async {
    if (value == null) return;
    ExposureState.hapticLight();
    if (!value) {
      setState(() {
        _addLocation = false;
        _placeName = null;
        _lat = null;
        _lng = null;
      });
      return;
    }

    // Request permission + position.
    setState(() => _locating = true);
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        _toast('Location services are off.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _toast('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      String? place;
      try {
        final marks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        final m = marks.isNotEmpty ? marks.first : null;
        if (m != null) {
          final bits = [
            m.locality,
            m.administrativeArea,
            m.country,
          ].where((s) => s != null && s.trim().isNotEmpty).take(2);
          place = bits.join(', ');
        }
      } catch (_) {
        place = null; // offline — keep coords only
      }
      setState(() {
        _addLocation = true;
        _lat = pos.latitude;
        _lng = pos.longitude;
        _placeName = place;
      });
    } catch (e) {
      _toast('Could not get location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    ExposureState.hapticMedium();

    try {
      String imagePath = widget.imagePath;

      // Always run bake to ensure 3:4 crop and orientation bake,
      // even if color simulation is turned off or is B&W.
      final out = await bakeFilmSim(
        sourcePath: imagePath,
        film: _bake ? widget.film : null,
        customLutMatrix: _bake ? widget.customLutMatrix : null,
      );
      if (out != null) {
        imagePath = out;
        // Evict from Flutter image cache so it reloads the baked file from disk
        await FileImage(File(imagePath)).evict();
      }

      await LogbookStore.instance.add(
        imagePath: imagePath,
        shutterSpeed: widget.snapshot.shutterSpeed,
        aperture: widget.snapshot.aperture,
        iso: widget.snapshot.iso,
        ev: widget.snapshot.ev,
        exposureCompensation: widget.snapshot.exposureCompensation,
        filmName: widget.snapshot.filmName,
        focalLength: widget.snapshot.focalLength,
        title: _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        latitude: _lat,
        longitude: _lng,
        placeName: _placeName,
        roll: _rollCtrl.text.trim(),
      );

      if (!mounted) return;
      // Replace the stack so back from the Logbook returns to the meter.
      Navigator.of(context).pushAndRemoveUntil(
        PageTransition(
          type: PageTransitionType.rightToLeft,
          child: const LogbookCoverScreen(autoOpenImmediate: true),
          curve: Curves.easeInOut,
          duration: const Duration(milliseconds: 350),
          reverseDuration: const Duration(milliseconds: 300),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Save failed: $e');
      }
    }
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this frame?'),
        content: const Text('The captured photo will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final f = File(widget.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.snapshot;
    final isBw = widget.film?.type == FilmType.blackWhite;

    return Scaffold(
      backgroundColor: LogbookTheme.paper(isDark),
      body: SafeArea(
        child: Column(
          children: [
            buildBookHeader(context, 'New Entry'),
            Expanded(
              child: LogbookTheme.paperBackground(
                isDark: isDark,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // Photo preview
                    FilmStripWrapper(
                      isDark: isDark,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: ColorFiltered(
                            colorFilter: (_bake && _hasColorFilm)
                                ? (widget.customLutMatrix != null
                                      ? ColorFilter.matrix(
                                          widget.customLutMatrix!,
                                        )
                                      : ColorFilter.matrix(
                                          filmSimMatrix(widget.film)!,
                                        ))
                                : const ColorFilter.matrix([
                                    1,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                  ]),
                            child: DevelopingPhoto(
                              imagePath: widget.imagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Film Roll field
                    Text(
                      'Film Roll',
                      style: stampStyle(
                        color: LogbookTheme.faded(isDark),
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF241F18)
                            : const Color(0xFFFBF6E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: LogbookTheme.faded(
                            isDark,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _rollCtrl,
                        maxLines: 1,
                        style: caveat(
                          size: 24,
                          color: LogbookTheme.ink(isDark),
                          weight: FontWeight.bold,
                        ),
                        cursorColor: LogbookTheme.ink(isDark),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Enter roll identifier (e.g. Roll #01)…',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title field
                    Text(
                      'Title',
                      style: stampStyle(
                        color: LogbookTheme.faded(isDark),
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF241F18)
                            : const Color(0xFFFBF6E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: LogbookTheme.faded(
                            isDark,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _titleCtrl,
                        maxLines: 1,
                        style: caveat(
                          size: 24,
                          color: LogbookTheme.ink(isDark),
                          weight: FontWeight.bold,
                        ),
                        cursorColor: LogbookTheme.ink(isDark),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Enter title (e.g. Fuji Superia 400)…',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Note field
                    Text(
                      'Note',
                      style: stampStyle(
                        color: LogbookTheme.faded(isDark),
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF241F18)
                            : const Color(0xFFFBF6E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: LogbookTheme.faded(
                            isDark,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: CustomPaint(
                        painter: LinedPaperPainter(
                          lineColor: LogbookTheme.faded(
                            isDark,
                          ).withValues(alpha: 0.25),
                          lineHeight: 23.0,
                          offsetTop: 20.0,
                        ),
                        child: TextField(
                          controller: _noteCtrl,
                          minLines: 4,
                          maxLines: 8,
                          style: caveat(
                            size: 20,
                            color: LogbookTheme.ink(isDark),
                            height:
                                1.15, // aligns with 23.0 lineHeight visually
                          ),
                          cursorColor: LogbookTheme.ink(isDark),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'Write something about this frame…',
                            contentPadding: EdgeInsets.only(top: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Auto-filled settings (read-only)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F1B15)
                            : const Color(0xFFEFE6CC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: LogbookTheme.faded(
                            isDark,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: stampStyle(
                              color: LogbookTheme.faded(isDark),
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _stamp(
                                'f/${s.aperture.toStringAsFixed(1)}',
                                isDark,
                              ),
                              _stamp(_fmtShutter(s.shutterSpeed), isDark),
                              _stamp('ISO ${s.iso}', isDark),
                              _stamp('EV ${s.ev.toStringAsFixed(1)}', isDark),
                              _stamp(
                                '${s.exposureCompensation >= 0 ? "+" : ""}${s.exposureCompensation.toStringAsFixed(1)} ev',
                                isDark,
                              ),
                              if (s.filmName != null)
                                _stamp(s.filmName!, isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bake toggle (only if a film-sim is applicable)
                    if (_hasColorFilm)
                      _toggleRow(
                        isDark,
                        icon: Icons.auto_fix_high_outlined,
                        label: isBw
                            ? 'Apply B&W film-sim look'
                            : 'Apply film-sim look',
                        value: _bake,
                        onChanged: (v) => setState(() => _bake = v ?? false),
                      ),
                    const SizedBox(height: 8),

                    // Location toggle
                    _toggleRow(
                      isDark,
                      icon: Icons.place_outlined,
                      label: _locating
                          ? 'Finding location…'
                          : (_addLocation
                                ? (_placeName ?? 'Location added')
                                : 'Add location'),
                      value: _addLocation,
                      onChanged: _locating ? null : _toggleLocation,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Save / Discard footer — floats above the scroll.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: LogbookTheme.paper(isDark),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : _discard,
                  child: Text(
                    'Discard',
                    style: caveat(size: 22, color: LogbookTheme.faded(isDark)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: LogbookTheme.ink(isDark),
                    foregroundColor: LogbookTheme.paper(isDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save',
                          style: caveat(size: 24, weight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stamp(String text, bool isDark) {
    return Text(
      text,
      style: stampStyle(color: LogbookTheme.ink(isDark), size: 16),
    );
  }

  Widget _toggleRow(
    bool isDark, {
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: LogbookTheme.ink(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: caveat(size: 20, color: LogbookTheme.ink(isDark)),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  static String _fmtShutter(double s) {
    if (s >= 1) return s.toStringAsFixed(s == s.roundToDouble() ? 0 : 1);
    final inv = (1 / s).round();
    return '1/$inv';
  }
}

class FilmStripWrapper extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const FilmStripWrapper({
    required this.child,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0E), // Charcoal black color
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _SprocketStrip(isDark: isDark),
            const SizedBox(width: 8),
            Expanded(child: child),
            const SizedBox(width: 8),
            _SprocketStrip(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _SprocketStrip extends StatelessWidget {
  final bool isDark;
  const _SprocketStrip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final holeColor = LogbookTheme.paper(isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          9,
          (index) => Container(
            width: 8,
            height: 12,
            decoration: BoxDecoration(
              color: holeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
