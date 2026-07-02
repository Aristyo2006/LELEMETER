import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_entry.dart';

/// Lightweight persistence for the Logbook.
///
/// - Metadata: a single JSON file (`<docs>/logbook.json`) holding a list of
///   [LogEntry] objects.
/// - Images: individual JPEG files under `<docs>/logbook_images/<id>.jpg`.
///
/// The whole list is held in memory and persisted write-behind (async, no
/// blocking UI). This avoids pulling in a DB dependency for what is a small
/// personal journal. Designed as a singleton.
class LogbookStore {
  LogbookStore._();
  static final LogbookStore instance = LogbookStore._();

  final List<LogEntry> _entries = [];
  List<LogEntry> get entries => List.unmodifiable(_entries);

  final List<LogFolder> _folders = [];
  List<LogFolder> get folders => List.unmodifiable(_folders);

  bool _loaded = false;
  File? _metaFile;
  Directory? _imageDir;

  /// Ensure storage is ready. Safe to call repeatedly.
  Future<void> ensureInitialized() async {
    if (_loaded) return;
    final docs = await getApplicationDocumentsDirectory();
    _imageDir = Directory(p.join(docs.path, 'logbook_images'));
    if (!_imageDir!.existsSync()) await _imageDir!.create(recursive: true);
    _metaFile = File(p.join(docs.path, 'logbook.json'));
    await _load();
    _loaded = true;
  }

  Future<void> _load() async {
    final f = _metaFile;
    if (f == null || !f.existsSync()) return;
    try {
      final raw = await f.readAsString();
      final parsed = jsonDecode(raw);
      _entries.clear();
      _folders.clear();
      if (parsed is List) {
        // Old format (just list of entries)
        _entries.addAll(parsed.map((e) => LogEntry.fromJson(e as Map<String, dynamic>)));
      } else if (parsed is Map<String, dynamic>) {
        // New format (folders and entries)
        if (parsed['folders'] != null) {
          final foldersList = parsed['folders'] as List;
          _folders.addAll(foldersList.map((folder) => LogFolder.fromJson(folder as Map<String, dynamic>)));
        }
        if (parsed['entries'] != null) {
          final entriesList = parsed['entries'] as List;
          _entries.addAll(entriesList.map((e) => LogEntry.fromJson(e as Map<String, dynamic>)));
        }
      }
      _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      // Corrupt meta → start fresh; never crash the app.
      _entries.clear();
      _folders.clear();
    }
  }

  Future<void> _persist() async {
    final f = _metaFile;
    if (f == null) return;
    final data = {
      'folders': _folders.map((folder) => folder.toJson()).toList(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
    };
    // Write atomically: temp file then rename.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  /// Copies (or moves) a captured image into the store and returns its path.
  /// The caller passes the temp path produced by the native capture.
  Future<String> importImage(String sourcePath, {bool move = true}) async {
    await ensureInitialized();
    final id = '${DateTime.now().millisecondsSinceEpoch}-${sourcePath.hashCode.abs()}';
    final dest = File(p.join(_imageDir!.path, '$id.jpg'));
    final src = File(sourcePath);
    if (await src.exists()) {
      if (move && p.dirname(sourcePath) != _imageDir!.path) {
        await src.rename(dest.path);
      } else {
        await src.copy(dest.path);
      }
    }
    return dest.path;
  }

  Future<LogFolder> addFolder(String name, {String note = '', int? colorValue}) async {
    await ensureInitialized();
    final folder = LogFolder.create(name, note: note, colorValue: colorValue);
    _folders.insert(0, folder);
    await _persist();
    return folder;
  }

  Future<void> updateFolder(LogFolder folder) async {
    await ensureInitialized();
    final i = _folders.indexWhere((f) => f.id == folder.id);
    if (i >= 0) _folders[i] = folder;
    await _persist();
  }

  Future<void> deleteFolder(String folderId) async {
    await ensureInitialized();
    _folders.removeWhere((f) => f.id == folderId);
    // Unassign this folder from all entries belonging to it
    for (final entry in _entries) {
      if (entry.folderId == folderId) {
        entry.folderId = null;
      }
    }
    await _persist();
  }

  Future<void> moveEntryToFolder(String entryId, String? folderId) async {
    await ensureInitialized();
    final i = _entries.indexWhere((e) => e.id == entryId);
    if (i >= 0) {
      _entries[i].folderId = folderId;
      await _persist();
    }
  }

  Future<LogEntry> add({
    required String imagePath,
    required double shutterSpeed,
    required double aperture,
    required int iso,
    required double ev,
    required double exposureCompensation,
    String? filmName,
    int? focalLength,
    String title = '',
    String note = '',
    double? latitude,
    double? longitude,
    String? placeName,
    String? folderId,
    String? roll,
  }) async {
    await ensureInitialized();
    final stored = await importImage(imagePath);
    final entry = LogEntry.create(
      imagePath: stored,
      shutterSpeed: shutterSpeed,
      aperture: aperture,
      iso: iso,
      ev: ev,
      exposureCompensation: exposureCompensation,
      filmName: filmName,
      focalLength: focalLength,
      title: title,
      note: note,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      folderId: folderId,
      roll: roll,
    );
    _entries.insert(0, entry);
    await _persist();
    return entry;
  }

  Future<void> update(LogEntry entry) async {
    await ensureInitialized();
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) _entries[i] = entry;
    await _persist();
  }

  Future<void> delete(String id) async {
    await ensureInitialized();
    final i = _entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final entry = _entries.removeAt(i);
    await _persist();
    // Best-effort image deletion; never throw.
    try {
      final f = File(entry.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
