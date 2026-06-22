import 'dart:convert';
import 'dart:math';

/// A single collection folder in the Logbook.
class LogFolder {
  final String id;
  String name;
  String note;
  int? colorValue; // Custom folder color (ARGB), null = use default manila
  final DateTime createdAt;

  LogFolder({
    required this.id,
    required this.name,
    this.note = '',
    this.colorValue,
    required this.createdAt,
  });

  factory LogFolder.create(String name, {String note = '', int? colorValue}) {
    final suffix = Random().nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
    return LogFolder(
      id: 'folder-${DateTime.now().millisecondsSinceEpoch}-$suffix',
      name: name,
      note: note,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        if (colorValue != null) 'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LogFolder.fromJson(Map<String, dynamic> j) => LogFolder(
        id: j['id'] as String,
        name: j['name'] as String,
        note: (j['note'] as String?) ?? '',
        colorValue: j['colorValue'] as int?,
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// A single Logbook entry.
///
/// The exposure fields below are a *snapshot* taken at capture time. They are
/// deliberately decoupled from [ExposureState] so a log entry never changes if
/// the user later adjusts the meter — and so this model has zero dependency on
/// the calculation/state layer.
class LogEntry {
  final String id;
  final String imagePath;
  String title;
  String note;
  final double? latitude;
  final double? longitude;
  String? placeName;
  final DateTime createdAt;
  String? folderId; // Link to containing collection folder
  String? roll;     // Film roll identifier (e.g. "Roll #01")

  // ── Exposure snapshot (read at capture, never recomputed) ──
  final double shutterSpeed; // seconds
  final double aperture; // f-number
  final int iso;
  final double ev;
  final double exposureCompensation;
  final String? filmName;

  LogEntry({
    required this.id,
    required this.imagePath,
    this.title = '',
    this.note = '',
    this.latitude,
    this.longitude,
    this.placeName,
    required this.createdAt,
    this.folderId,
    this.roll,
    required this.shutterSpeed,
    required this.aperture,
    required this.iso,
    required this.ev,
    required this.exposureCompensation,
    this.filmName,
  });

  factory LogEntry.create({
    required String imagePath,
    required double shutterSpeed,
    required double aperture,
    required int iso,
    required double ev,
    required double exposureCompensation,
    String? filmName,
    String title = '',
    String note = '',
    double? latitude,
    double? longitude,
    String? placeName,
    String? folderId,
    String? roll,
  }) {
    final rng = Random();
    final suffix = rng.nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
    return LogEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}-$suffix',
      imagePath: imagePath,
      title: title,
      note: note,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      createdAt: DateTime.now(),
      folderId: folderId,
      roll: roll,
      shutterSpeed: shutterSpeed,
      aperture: aperture,
      iso: iso,
      ev: ev,
      exposureCompensation: exposureCompensation,
      filmName: filmName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'title': title,
        'note': note,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (placeName != null) 'placeName': placeName,
        'createdAt': createdAt.toIso8601String(),
        if (folderId != null) 'folderId': folderId,
        if (roll != null) 'roll': roll,
        'shutterSpeed': shutterSpeed,
        'aperture': aperture,
        'iso': iso,
        'ev': ev,
        'exposureCompensation': exposureCompensation,
        if (filmName != null) 'filmName': filmName,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: j['id'] as String,
        imagePath: j['imagePath'] as String,
        title: (j['title'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        placeName: j['placeName'] as String?,
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        folderId: j['folderId'] as String?,
        roll: j['roll'] as String?,
        shutterSpeed: (j['shutterSpeed'] as num).toDouble(),
        aperture: (j['aperture'] as num).toDouble(),
        iso: (j['iso'] as num).toInt(),
        ev: (j['ev'] as num).toDouble(),
        exposureCompensation: (j['exposureCompensation'] as num).toDouble(),
        filmName: j['filmName'] as String?,
      );

  /// A compact settings string, e.g. "f/2.8 · 1/30 · ISO 400 · EV 12.5".
  static String settingsLine({
    required double shutterSpeed,
    required double aperture,
    required int iso,
    required double ev,
    String? filmName,
  }) {
    final parts = <String>[
      'f/${aperture.toStringAsFixed(1)}',
      _formatShutter(shutterSpeed),
      'ISO $iso',
      'EV ${ev.toStringAsFixed(1)}',
    ];
    if (filmName != null && filmName.isNotEmpty) parts.add(filmName);
    return parts.join(' · ');
  }

  static String _formatShutter(double s) {
    if (s >= 1) return s.toStringAsFixed(s == s.roundToDouble() ? 0 : 1);
    final inv = (1 / s).round();
    return '1/$inv';
  }

  String get settings => settingsLine(
        shutterSpeed: shutterSpeed,
        aperture: aperture,
        iso: iso,
        ev: ev,
        filmName: filmName,
      );
}

/// Convenience encode/decode for the persistence layer (a JSON array of entries).
String encodeEntries(List<LogEntry> entries) =>
    jsonEncode(entries.map((e) => e.toJson()).toList());

List<LogEntry> decodeEntries(String raw) {
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}
