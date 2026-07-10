import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:animations/animations.dart';
import 'package:share_plus/share_plus.dart';

import '../exposure_state.dart';
import 'log_entry.dart';
import 'logbook_store.dart';
import 'logbook_theme.dart';
import 'logbook_screen.dart';

class LogDetailScreen extends StatefulWidget {
  final LogEntry entry;
  final bool startInEditMode;
  const LogDetailScreen({
    super.key,
    required this.entry,
    this.startInEditMode = false,
  });

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  late LogEntry _entry;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _rollCtrl;
  late final ScrollController _scrollController;
  bool _editing = false;
  bool _busy = false;
  bool _showFolderPicker = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _titleCtrl = TextEditingController(text: _entry.title);
    _noteCtrl = TextEditingController(text: _entry.note);
    _rollCtrl = TextEditingController(text: _entry.roll ?? '');
    _scrollController = ScrollController();
    _editing = widget.startInEditMode;

    if (widget.startInEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _rollCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

  Future<void> _saveEdit() async {
    _entry.title = _titleCtrl.text.trim();
    _entry.note = _noteCtrl.text.trim();
    _entry.roll = _rollCtrl.text.trim().isEmpty ? null : _rollCtrl.text.trim();
    await LogbookStore.instance.update(_entry);
    if (!mounted) return;
    setState(() {
      _editing = false;
      _changed = true;
    });
    _toast('Saved');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This photo and its notes will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LogbookStore.instance.delete(_entry.id);
    if (!mounted) return;
    Navigator.of(context).pop(true); // tell list to refresh
  }

  Future<void> _exportGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = File(_entry.imagePath);
      if (!await file.exists()) {
        _toast('Photo file missing.');
        return;
      }
      await Gal.putImage(_entry.imagePath, album: 'Lelemeter');
      _toast('Saved to gallery');
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        await Gal.requestAccess();
        _toast('Permission needed — try again.');
      } else {
        _toast('Could not save: ${e.type}');
      }
    } catch (_) {
      _toast('Could not save to gallery.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = File(_entry.imagePath);
      if (!await file.exists()) {
        _toast('Photo file missing.');
        return;
      }
      await Share.shareXFiles(
        [XFile(_entry.imagePath)],
        text: _entry.note.trim().isEmpty
            ? 'Lelemeter — ${_entry.settings}'
            : '${_entry.note.trim()}\n${_entry.settings}',
      );
    } catch (_) {
      _toast('Sharing failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: LogbookTheme.paper(isDark),
      body: SafeArea(
        child: Column(
          children: [
            buildBookHeader(
              context,
              _entry.title.trim().isEmpty
                  ? (_entry.filmName ?? 'Untitled frame')
                  : _entry.title.trim(),
              onBack: () {
                Navigator.of(context).pop(_changed);
              },
            ),
            Expanded(
              child: LogbookTheme.paperBackground(
                isDark: isDark,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // Full photo with physical "tipped-in" frame and tape
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          OpenContainer(
                            transitionType: ContainerTransitionType.fade,
                            transitionDuration: const Duration(
                              milliseconds: 600,
                            ),
                            closedColor: Colors.transparent,
                            closedElevation: 0,
                            openElevation: 0,
                            middleColor: Colors.transparent,
                            openColor: Colors.black,
                            clipBehavior: Clip.none,
                            openBuilder: (context, action) {
                              return Scaffold(
                                backgroundColor: Colors.black,
                                body: Stack(
                                  children: [
                                    InteractiveViewer(
                                      minScale: 1.0,
                                      maxScale: 5.0,
                                      child: SizedBox.expand(
                                        child: Image.file(
                                          File(_entry.imagePath),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: SafeArea(
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            closedBuilder: (context, action) {
                              return Transform.rotate(
                                angle: -0.02, // 1 degree tilt to the left
                                child: GestureDetector(
                                  onTap: () {
                                    ExposureState.hapticLight();
                                    action();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      28,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFBF6E9),
                                      border: Border.all(
                                        color: LogbookTheme.faded(
                                          false,
                                        ).withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.35 : 0.12,
                                          ),
                                          offset: const Offset(2, 4),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                          child: Hero(
                                            tag: 'entry_image_${_entry.id}',
                                            child: Image.file(
                                              File(_entry.imagePath),
                                              fit: BoxFit.contain,
                                              gaplessPlayback: true,
                                              cacheWidth: 1200,
                                              errorBuilder:
                                                  (
                                                    ctx,
                                                    error,
                                                    stackTrace,
                                                  ) => AspectRatio(
                                                    aspectRatio: 3 / 4,
                                                    child: Container(
                                                      color: Colors.black12,
                                                      child: Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        size: 56,
                                                        color:
                                                            LogbookTheme.faded(
                                                              isDark,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _fullDateCaption(_entry.createdAt),
                                          style: caveat(
                                            size: 19,
                                            color: const Color(0xFF5A4E44),
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Decorative Washi Tape 1 (Top Left)
                          Positioned(
                            top: -8,
                            left: 40,
                            child: Transform.rotate(
                              angle: -0.08,
                              child: Container(
                                width: 50,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD2C8B4,
                                  ).withValues(alpha: 0.35),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Decorative Washi Tape 2 (Top Right)
                          Positioned(
                            top: -6,
                            right: 40,
                            child: Transform.rotate(
                              angle: 0.05,
                              child: Container(
                                width: 45,
                                height: 15,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD2C8B4,
                                  ).withValues(alpha: 0.3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Detailed Parameters Block (glued index card style)
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1B1713)
                                : const Color(0xFFFAF2DC),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: LogbookTheme.faded(
                                isDark,
                              ).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.20 : 0.05,
                                ),
                                offset: const Offset(1, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXIF PARAMETERS',
                                style: stampStyle(
                                  color: LogbookTheme.faded(isDark),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_entry.focalLength != null) ...[
                                _exifParamRow(
                                  Icons.center_focus_strong_outlined,
                                  'Focal Length',
                                  '${_entry.focalLength}mm',
                                  isDark,
                                ),
                                const SizedBox(height: 6),
                              ],
                              _exifParamRow(
                                Icons.camera_outlined,
                                'Aperture',
                                'f/${_entry.aperture.toStringAsFixed(1)}',
                                isDark,
                              ),
                              const SizedBox(height: 6),
                              _exifParamRow(
                                Icons.shutter_speed_outlined,
                                'Shutter Speed',
                                _fmtShutter(_entry.shutterSpeed),
                                isDark,
                              ),
                              const SizedBox(height: 6),
                              _exifParamRow(
                                Icons.speed,
                                'ISO',
                                '${_entry.iso}',
                                isDark,
                              ),
                              const SizedBox(height: 6),
                              _exifParamRow(
                                Icons.wb_sunny_outlined,
                                'EV (Exposure Value)',
                                _entry.ev.toStringAsFixed(1),
                                isDark,
                              ),
                              const SizedBox(height: 6),
                              _exifParamRow(
                                Icons.exposure_outlined,
                                'Exposure Comp.',
                                '${_entry.exposureCompensation >= 0 ? "+" : ""}${_entry.exposureCompensation.toStringAsFixed(1)} EV',
                                isDark,
                              ),
                              if (_entry.filmName != null) ...[
                                const SizedBox(height: 6),
                                _exifParamRow(
                                  Icons.movie_filter_outlined,
                                  'Film Simulator',
                                  _entry.filmName!,
                                  isDark,
                                ),
                              ],
                              if (_entry.roll != null &&
                                  _entry.roll!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _exifParamRow(
                                  Icons.camera_roll_outlined,
                                  'Film Roll',
                                  _entry.roll!.toUpperCase(),
                                  isDark,
                                ),
                              ],
                              const SizedBox(height: 6),
                              _exifParamRow(
                                Icons.calendar_today_outlined,
                                'Captured At',
                                _fullDate(_entry.createdAt),
                                isDark,
                              ),
                              if (_entry.placeName != null) ...[
                                const SizedBox(height: 6),
                                _exifParamRow(
                                  Icons.place_outlined,
                                  'Location',
                                  _entry.placeName!,
                                  isDark,
                                ),
                              ],
                              if (_entry.latitude != null) ...[
                                const SizedBox(height: 6),
                                _exifParamRow(
                                  Icons.my_location_outlined,
                                  'GPS Coordinates',
                                  '${_entry.latitude!.toStringAsFixed(4)}, ${_entry.longitude!.toStringAsFixed(4)}',
                                  isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Tilted red rubber stamp in top right
                        Positioned(
                          top: 8,
                          right: 12,
                          child: Transform.rotate(
                            angle: -0.08,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.red.withValues(
                                    alpha: isDark ? 0.35 : 0.45,
                                  ),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'EXIF DATA',
                                style: stampStyle(
                                  color: Colors.red.withValues(
                                    alpha: isDark ? 0.45 : 0.55,
                                  ),
                                  size: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Title & Note (View / Edit mode)
                    if (_editing) ...[
                      Text(
                        'Edit Title',
                        style: stampStyle(
                          color: LogbookTheme.faded(isDark),
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF241F18)
                              : const Color(0xFFFBF6E9),
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
                      const SizedBox(height: 16),
                      Text(
                        'Edit Film Roll',
                        style: stampStyle(
                          color: LogbookTheme.faded(isDark),
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF241F18)
                              : const Color(0xFFFBF6E9),
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
                            hintText: 'Enter film roll (e.g. ROLL 01)…',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Edit Note',
                        style: stampStyle(
                          color: LogbookTheme.faded(isDark),
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF241F18)
                              : const Color(0xFFFBF6E9),
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
                              height: 1.15,
                            ),
                            cursorColor: LogbookTheme.ink(isDark),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Write something about this frame…',
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Title (handwritten)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _entry.title.trim().isEmpty
                              ? (_entry.filmName ?? 'Untitled frame')
                              : _entry.title.trim(),
                          style: caveat(
                            size: 32,
                            weight: FontWeight.bold,
                            color: LogbookTheme.ink(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Lined description/notes paper block
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF241F18)
                              : const Color(0xFFFBF6E9),
                          border: Border.all(
                            color: LogbookTheme.faded(
                              isDark,
                            ).withValues(alpha: 0.25),
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
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              _entry.note.trim().isEmpty
                                  ? 'No notes for this frame.'
                                  : _entry.note.trim(),
                              style: caveat(
                                size: 20,
                                color: _entry.note.trim().isEmpty
                                    ? LogbookTheme.faded(isDark)
                                    : LogbookTheme.ink(isDark),
                                height: 1.15, // aligns with 23.0 lineHeight
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_editing) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saveEdit,
                              icon: const Icon(Icons.check),
                              label: Text(
                                'Save',
                                style: caveat(
                                  size: 22,
                                  weight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: LogbookTheme.ink(isDark),
                                foregroundColor: LogbookTheme.paper(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: _actionTile(
                            isDark,
                            icon: _editing
                                ? Icons.edit_off_outlined
                                : Icons.edit_outlined,
                            label: _editing ? 'Cancel' : 'Edit',
                            onTap: _busy
                                ? null
                                : () {
                                    ExposureState.hapticLight();
                                    setState(() => _editing = !_editing);
                                    if (!_editing) {
                                      _noteCtrl.text = _entry.note;
                                      _titleCtrl.text = _entry.title;
                                      _rollCtrl.text = _entry.roll ?? '';
                                    } else {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            _scrollToBottom();
                                          });
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionTile(
                            isDark,
                            icon: Icons.download_outlined,
                            label: 'Save',
                            onTap: _busy ? null : _exportGallery,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionTile(
                            isDark,
                            icon: Icons.ios_share,
                            label: 'Share',
                            onTap: _busy ? null : _share,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionTile(
                            isDark,
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            danger: true,
                            onTap: _busy ? null : _delete,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCollectionSection(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String entryPlaceHolder() => _entry.filmName ?? 'Untitled frame';

  Widget _actionTile(
    bool isDark, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFD46A6A) : LogbookTheme.ink(isDark);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              ExposureState.hapticLight();
              onTap();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: caveat(size: 18, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _exifParamRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: LogbookTheme.faded(isDark)),
        const SizedBox(width: 8),
        Text(
          label,
          style: stampStyle(color: LogbookTheme.faded(isDark), size: 15),
        ),
        const Spacer(),
        Text(
          value,
          style: stampStyle(color: LogbookTheme.ink(isDark), size: 15),
        ),
      ],
    );
  }

  static String _fmtShutter(double s) {
    if (s >= 1) return s.toStringAsFixed(s == s.roundToDouble() ? 0 : 1);
    final inv = (1 / s).round();
    return '1/$inv';
  }

  static String _fullDate(DateTime dt) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month]} ${dt.day}, ${dt.year} · $h:$m';
  }

  String _fullDateCaption(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Captured ${months[dt.month]} ${dt.day}, ${dt.year} @ $h:$m';
  }

  Widget _buildCollectionSection(bool isDark) {
    final currentFolderId = _entry.folderId;
    final LogFolder? currentFolder = currentFolderId != null
        ? LogbookStore.instance.folders.firstWhere(
            (f) => f.id == currentFolderId,
            orElse: () =>
                LogFolder(id: '', name: 'Unknown', createdAt: DateTime.now()),
          )
        : null;

    final hasCollection = currentFolder != null && currentFolder.id.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            ExposureState.hapticLight();
            setState(() {
              _showFolderPicker = !_showFolderPicker;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9),
              border: Border.all(
                color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(0),
            ),
            child: Row(
              children: [
                Icon(
                  hasCollection ? Icons.folder : Icons.folder_open_outlined,
                  size: 18,
                  color: LogbookTheme.ink(isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasCollection
                        ? 'COLLECTION: ${currentFolder.name.toUpperCase()}'
                        : 'ADD TO COLLECTION',
                    style: stampStyle(
                      color: LogbookTheme.ink(isDark),
                      size: 15,
                    ),
                  ),
                ),
                Icon(
                  _showFolderPicker
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: LogbookTheme.faded(isDark),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showFolderPicker
              ? Container(
                  key: const ValueKey('folder_picker_open'),
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B1713)
                        : const Color(0xFFFAF2DC),
                    border: Border.all(
                      color: LogbookTheme.faded(isDark).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.folder_off_outlined,
                          size: 16,
                          color: LogbookTheme.ink(isDark),
                        ),
                        title: Text(
                          'No Collection (Unassign)',
                          style: caveat(
                            size: 18,
                            color: LogbookTheme.ink(isDark),
                            weight: currentFolderId == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () async {
                          ExposureState.hapticLight();
                          await LogbookStore.instance.moveEntryToFolder(
                            _entry.id,
                            null,
                          );
                          setState(() {
                            _entry.folderId = null;
                            _changed = true;
                            _showFolderPicker = false;
                          });
                          _toast('Removed from collection');
                        },
                      ),
                      const Divider(height: 1),
                      ...LogbookStore.instance.folders.map((folder) {
                        final isCurrent = folder.id == currentFolderId;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isCurrent ? Icons.folder : Icons.folder_outlined,
                            size: 16,
                            color: isCurrent
                                ? LogbookTheme.faded(isDark)
                                : LogbookTheme.ink(isDark),
                          ),
                          title: Text(
                            folder.name,
                            style: caveat(
                              size: 18,
                              weight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: LogbookTheme.ink(isDark),
                            ),
                          ),
                          onTap: () async {
                            ExposureState.hapticLight();
                            await LogbookStore.instance.moveEntryToFolder(
                              _entry.id,
                              folder.id,
                            );
                            setState(() {
                              _entry.folderId = folder.id;
                              _changed = true;
                              _showFolderPicker = false;
                            });
                            _toast('Moved to ${folder.name}');
                          },
                        );
                      }),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.add,
                          size: 16,
                          color: LogbookTheme.ink(isDark),
                        ),
                        title: Text(
                          'Create New Folder…',
                          style: caveat(
                            size: 18,
                            color: LogbookTheme.ink(isDark),
                          ),
                        ),
                        onTap: () {
                          ExposureState.hapticLight();
                          _showCreateFolderFromDetails(isDark);
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  key: ValueKey('folder_picker_closed'),
                  width: double.infinity,
                  height: 0,
                ),
        ),
      ],
    );
  }

  void _showCreateFolderFromDetails(bool isDark) {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int? selectedColor;

    showDialog(
      context: context,
      builder: (ctx) {
        final inkColor = LogbookTheme.ink(isDark);
        return StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            backgroundColor: LogbookTheme.paper(isDark),
            title: Text(
              'New Folder',
              style: caveat(size: 26, weight: FontWeight.bold, color: inkColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: caveat(size: 20, color: inkColor),
                  cursorColor: inkColor,
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    labelStyle: stampStyle(color: LogbookTheme.faded(isDark)),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: inkColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  style: caveat(size: 20, color: inkColor),
                  cursorColor: inkColor,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: stampStyle(color: LogbookTheme.faded(isDark)),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: inkColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FolderColorPicker(
                  selectedColor: selectedColor,
                  onColorSelected: (c) => setInner(() => selectedColor = c),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: caveat(size: 20, color: LogbookTheme.faded(isDark)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    final folder = await LogbookStore.instance.addFolder(
                      name,
                      note: noteCtrl.text.trim(),
                      colorValue: selectedColor,
                    );
                    await LogbookStore.instance.moveEntryToFolder(
                      _entry.id,
                      folder.id,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _entry.folderId = folder.id;
                      _changed = true;
                      _showFolderPicker = false;
                    });
                    _toast('Created and moved to ${folder.name}');
                  }
                },
                child: Text(
                  'Create',
                  style: caveat(
                    size: 20,
                    weight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
