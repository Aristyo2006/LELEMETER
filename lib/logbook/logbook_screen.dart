import 'dart:io';

import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../camera_viewfinder_screen.dart';
import '../exposure_state.dart';
import 'log_entry.dart';
import 'logbook_store.dart';
import 'logbook_theme.dart';
import 'log_detail_screen.dart';

enum LogbookSortOrder {
  dateDescending,
  dateAscending,
  titleAZ,
}

/// The Logbook list — opened from the bottom-nav LOG button.
class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  List<LogEntry> _entries = const [];
  List<LogEntry> _sortedEntries = const [];
  Map<String, List<LogEntry>> _folderEntriesMap = {};
  bool _loading = true;
  LogbookSortOrder _sortOrder = LogbookSortOrder.dateDescending;
  bool _compactMode = false;
  int _currentTab = 0; // 0 = Frames, 1 = Collections
  LogFolder? _activeFolder; // Filtered collection active

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTab);
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await LogbookStore.instance.ensureInitialized();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _entries = LogbookStore.instance.entries;
      _loading = false;
      _compactMode = prefs.getBool('logbook_compact_mode') ?? false;
    });
    _updateProcessedData();
  }

  void _updateProcessedData() {
    // 1. Handle sorting and filtering for the main list
    final filtered = _activeFolder != null
        ? _entries.where((e) => e.folderId == _activeFolder!.id).toList()
        : List<LogEntry>.from(_entries);

    if (_sortOrder == LogbookSortOrder.dateDescending) {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortOrder == LogbookSortOrder.dateAscending) {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_sortOrder == LogbookSortOrder.titleAZ) {
      filtered.sort((a, b) {
        final titleA = a.title.trim().isEmpty ? (a.filmName ?? '') : a.title;
        final titleB = b.title.trim().isEmpty ? (b.filmName ?? '') : b.title;
        return titleA.toLowerCase().compareTo(titleB.toLowerCase());
      });
    }
    _sortedEntries = filtered;

    // 2. Pre-calculate entries per folder to avoid O(N*F) in builder
    final folderMap = <String, List<LogEntry>>{};
    for (final e in _entries) {
      if (e.folderId != null) {
        folderMap.putIfAbsent(e.folderId!, () => []).add(e);
      }
    }
    _folderEntriesMap = folderMap;
  }

  Future<void> _openDetail(LogEntry entry, {bool startInEditMode = false}) async {
    // Pre-decode the image at the EXACT size the detail screen will display
    // (cacheWidth 1200), so the Hero transition doesn't stall on first decode.
    // Plain FileImage would decode at native res → different cache key → wasted.
    precacheImage(
      ResizeImage(FileImage(File(entry.imagePath)), width: 1200),
      context,
    );

    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LogDetailScreen(entry: entry, startInEditMode: startInEditMode)),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _openViewfinder() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnalogViewfinderScreen()),
    );
    // Refresh in case a capture produced a new entry.
    if (mounted) _load();
  }

  void _showContextMenu(BuildContext context, LogEntry entry, Offset position, {VoidCallback? onEdit}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9);
    final inkColor = LogbookTheme.ink(isDark);

    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 30, 30),
        Offset.zero & overlay.size,
      ),
      color: paperColor,
      shape: Border.all(
        color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
        width: 1,
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: inkColor, size: 18),
              const SizedBox(width: 10),
              Text('Edit Details', style: caveat(size: 20, color: inkColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.folder_open_outlined, color: inkColor, size: 18),
              const SizedBox(width: 10),
              Text('Move to Folder', style: caveat(size: 20, color: inkColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: const Color(0xFFD46A6A), size: 18),
              const SizedBox(width: 10),
              Text('Delete Frame', style: caveat(size: 20, color: const Color(0xFFD46A6A))),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;
    if (selected == 'edit') {
      if (onEdit != null) {
        onEdit();
      } else {
        _openDetail(entry, startInEditMode: true);
      }
    } else if (selected == 'move') {
      _showMoveToFolderDialog(entry);
    } else if (selected == 'delete') {
      _confirmDelete(entry);
    }
  }

  void _showMoveToFolderDialog(LogEntry entry) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await LogbookStore.instance.ensureInitialized();
    final folders = LogbookStore.instance.folders;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final inkColor = LogbookTheme.ink(isDark);
        return AlertDialog(
          backgroundColor: LogbookTheme.paper(isDark),
          title: Text(
            'Move to Folder',
            style: caveat(size: 26, weight: FontWeight.bold, color: inkColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(Icons.folder_off_outlined, color: inkColor),
                  title: Text(
                    'No Folder (Unassign)',
                    style: caveat(size: 22, color: inkColor),
                  ),
                  onTap: () async {
                    await LogbookStore.instance.moveEntryToFolder(entry.id, null);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  },
                ),
                const Divider(height: 1),
                ...folders.map((folder) {
                  final isCurrent = entry.folderId == folder.id;
                  return ListTile(
                    leading: Icon(
                      isCurrent ? Icons.folder : Icons.folder_outlined,
                      color: isCurrent ? LogbookTheme.faded(isDark) : inkColor,
                    ),
                    title: Text(
                      folder.name,
                      style: caveat(
                        size: 22,
                        weight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: inkColor,
                      ),
                    ),
                    onTap: () async {
                      await LogbookStore.instance.moveEntryToFolder(entry.id, folder.id);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _load();
                    },
                  );
                }),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.add, color: inkColor),
                  title: Text(
                    'Create New Folder…',
                    style: caveat(size: 22, color: inkColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateFolderDialog(entry);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog(LogEntry? moveAfterCreate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int? selectedColor; // null = default manila

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
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: inkColor)),
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
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: inkColor)),
                  ),
                ),
                const SizedBox(height: 16),
                // Color swatches
                _FolderColorPicker(
                  selectedColor: selectedColor,
                  onColorSelected: (c) => setInner(() => selectedColor = c),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: caveat(size: 20, color: LogbookTheme.faded(isDark))),
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
                    if (moveAfterCreate != null) {
                      await LogbookStore.instance.moveEntryToFolder(moveAfterCreate.id, folder.id);
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  }
                },
                child: Text('Create', style: caveat(size: 20, weight: FontWeight.bold, color: inkColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(LogEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This photo and its notes will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LogbookStore.instance.delete(entry.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeIn,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Scaffold(
            backgroundColor: LogbookTheme.paper(isDark),
            body: SafeArea(
              child: Column(
                children: [
                  if (_activeFolder != null)
                    buildBookHeader(
                      context,
                      _activeFolder!.name,
                      subtitle: 'Collection Archive',
                      onBack: () {
                        ExposureState.hapticLight();
                        setState(() => _activeFolder = null);
                        _updateProcessedData();
                      },
                      actions: [
                        _buildSortButton(isDark),
                      ],
                    )
                  else
                    buildBookHeader(
                      context,
                      'Logbook',
                      subtitle: '${_entries.length} ${_entries.length == 1 ? "entry" : "entries"}',
                      actions: [
                        _buildSortButton(isDark),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            ExposureState.hapticLight();
                            final newVal = !_compactMode;
                            setState(() => _compactMode = newVal);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('logbook_compact_mode', newVal);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              _compactMode ? Icons.grid_view : Icons.view_list,
                              color: LogbookTheme.ink(isDark),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            ExposureState.hapticLight();
                            _openViewfinder();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: LogbookTheme.ink(isDark),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_activeFolder == null)
                    Container(
                      color: LogbookTheme.paper(isDark),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _tabButton(0, 'ALL FRAMES', isDark),
                          const SizedBox(width: 8),
                          _tabButton(1, 'COLLECTIONS', isDark),
                        ],
                      ),
                    ),
                  Expanded(
                    child: LogbookTheme.paperBackground(
                      isDark: isDark,
                      child: _activeFolder != null
                          ? _framesTabBody(isDark)
                          : PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                ExposureState.hapticSelection();
                                setState(() {
                                  _currentTab = index;
                                });
                              },
                              children: [
                                _framesTabBody(isDark),
                                _collectionsTabBody(isDark),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabButton(int index, String label, bool isDark) {
    final active = _currentTab == index;
    final inkColor = LogbookTheme.ink(isDark);
    final fadedColor = LogbookTheme.faded(isDark);

    return GestureDetector(
      onTap: () {
        ExposureState.hapticLight();
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF2E2922) : const Color(0xFFEFE6CC))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? fadedColor.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: stampStyle(
            color: active ? inkColor : fadedColor,
            size: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(bool isDark) {
    return PopupMenuButton<LogbookSortOrder>(
      icon: Icon(
        Icons.sort,
        color: LogbookTheme.ink(isDark),
        size: 22,
      ),
      color: isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9),
      shape: Border.all(
        color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
        width: 1,
      ),
      onSelected: (order) {
        ExposureState.hapticLight();
        setState(() {
          _sortOrder = order;
        });
        _updateProcessedData();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: LogbookSortOrder.dateDescending,
          child: Text(
            'Newest First',
            style: caveat(
              size: 20,
              color: LogbookTheme.ink(isDark),
              weight: _sortOrder == LogbookSortOrder.dateDescending ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        PopupMenuItem(
          value: LogbookSortOrder.dateAscending,
          child: Text(
            'Oldest First',
            style: caveat(
              size: 20,
              color: LogbookTheme.ink(isDark),
              weight: _sortOrder == LogbookSortOrder.dateAscending ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        PopupMenuItem(
          value: LogbookSortOrder.titleAZ,
          child: Text(
            'Title (A-Z)',
            style: caveat(
              size: 20,
              color: LogbookTheme.ink(isDark),
              weight: _sortOrder == LogbookSortOrder.titleAZ ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _framesTabBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_sortedEntries.isEmpty) {
      return _empty(isDark, isFiltered: _activeFolder != null);
    }

    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      child: ListView.builder(
        key: ValueKey(_compactMode),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: _sortedEntries.length,
        itemBuilder: (context, i) {
          final entry = _sortedEntries[i];
          Offset tapPosition = Offset.zero;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              tapPosition = details.globalPosition;
            },
            child: _LogEntryContainer(
              entry: entry,
              compactMode: _compactMode,
              isDark: isDark,
              onClosed: () {
                if (mounted) _load();
              },
              onLongPress: (triggerEdit) {
                _showContextMenu(context, entry, tapPosition, onEdit: triggerEdit);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _collectionsTabBody(bool isDark) {
    final folders = LogbookStore.instance.folders;
    final totalCount = folders.length + 1;

    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      child: !_compactMode
          ? GridView.builder(
              key: const ValueKey('folders_grid'),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.76,
              ),
              itemCount: totalCount,
              itemBuilder: (context, i) {
                if (i == folders.length) {
                  return _CreateFolderCard(
                    onTap: () {
                      ExposureState.hapticLight();
                      _showCreateFolderDialog(null);
                    },
                    isGrid: true,
                  );
                }
                final folder = folders[i];
                final folderEntries = _folderEntriesMap[folder.id] ?? [];
                return Hero(
                  tag: 'folder_card_${folder.id}',
                  child: OpenContainer(
                    transitionType: ContainerTransitionType.fade,
                    transitionDuration: const Duration(milliseconds: 600),
                    closedColor: Colors.transparent,
                    closedElevation: 0,
                    openElevation: 0,
                    middleColor: Colors.transparent,
                    openColor: LogbookTheme.paper(isDark),
                    onClosed: (_) {
                      if (mounted) _load();
                    },
                    openBuilder: (context, action) => FolderDetailScreen(folder: folder),
                    closedBuilder: (context, action) => _FolderCard(
                      folder: folder,
                      folderEntries: folderEntries,
                      onTap: () {
                        ExposureState.hapticLight();
                        action();
                      },
                      onLongPress: () {
                        ExposureState.hapticMedium();
                        _showFolderContextMenu(context, folder);
                      },
                      isGrid: true,
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              key: const ValueKey('folders_list'),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
              itemCount: totalCount,
              itemBuilder: (context, i) {
                if (i == folders.length) {
                  return _CreateFolderCard(
                    onTap: () {
                      ExposureState.hapticLight();
                      _showCreateFolderDialog(null);
                    },
                    isGrid: false,
                  );
                }
                final folder = folders[i];
                final folderEntries = _folderEntriesMap[folder.id] ?? [];
                return Hero(
                  tag: 'folder_card_${folder.id}',
                  child: OpenContainer(
                    transitionType: ContainerTransitionType.fade,
                    transitionDuration: const Duration(milliseconds: 600),
                    closedColor: Colors.transparent,
                    closedElevation: 0,
                    openElevation: 0,
                    middleColor: Colors.transparent,
                    openColor: LogbookTheme.paper(isDark),
                    onClosed: (_) {
                      if (mounted) _load();
                    },
                    openBuilder: (context, action) => FolderDetailScreen(folder: folder),
                    closedBuilder: (context, action) => _FolderCard(
                      folder: folder,
                      folderEntries: folderEntries,
                      onTap: () {
                        ExposureState.hapticLight();
                        action();
                      },
                      onLongPress: () {
                        ExposureState.hapticMedium();
                        _showFolderContextMenu(context, folder);
                      },
                      isGrid: false,
                    ),
                  ),
                );
              },
            ),
    );
  }



  void _showFolderContextMenu(BuildContext context, LogFolder folder) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9);
    final inkColor = LogbookTheme.ink(isDark);

    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 200, 100, 200),
      color: paperColor,
      shape: Border.all(
        color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
        width: 1,
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: inkColor, size: 18),
              const SizedBox(width: 10),
              Text('Edit Archive Info', style: caveat(size: 20, color: inkColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: const Color(0xFFD46A6A), size: 18),
              const SizedBox(width: 10),
              Text('Delete Archive', style: caveat(size: 20, color: const Color(0xFFD46A6A))),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;
    if (selected == 'edit') {
      _showEditFolderDialog(folder);
    } else if (selected == 'delete') {
      _confirmDeleteFolder(folder);
    }
  }

  void _showEditFolderDialog(LogFolder folder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: folder.name);
    final noteCtrl = TextEditingController(text: folder.note);
    int? selectedColor = folder.colorValue;

    showDialog(
      context: context,
      builder: (ctx) {
        final inkColor = LogbookTheme.ink(isDark);
        return StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            backgroundColor: LogbookTheme.paper(isDark),
            title: Text(
              'Edit Archive Info',
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
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: inkColor)),
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
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: inkColor)),
                  ),
                ),
                const SizedBox(height: 16),
                _FolderColorPicker(
                  selectedColor: selectedColor,
                  onColorSelected: (c) => setInner(() => selectedColor = c),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: caveat(size: 20, color: LogbookTheme.faded(isDark))),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    folder.name = name;
                    folder.note = noteCtrl.text.trim();
                    folder.colorValue = selectedColor;
                    await LogbookStore.instance.updateFolder(folder);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  }
                },
                child: Text('Save', style: caveat(size: 20, weight: FontWeight.bold, color: inkColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteFolder(LogFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Archive Folder?'),
        content: const Text('This will delete the folder but KEEP all your photo entries inside it (they will be unassigned).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LogbookStore.instance.deleteFolder(folder.id);
      _load();
    }
  }

  Widget _empty(bool isDark, {bool isFiltered = false}) {
    return LogbookTheme.paperBackground(
      isDark: isDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 72,
                color: LogbookTheme.faded(isDark),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered ? 'Archive empty' : 'No frames yet',
                style: caveat(
                  size: 30,
                  weight: FontWeight.bold,
                  color: LogbookTheme.ink(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFiltered
                    ? 'Long press frames in the main list to move them to this archive.'
                    : 'Open the viewfinder, capture a frame,\nand it will be filed here.',
                textAlign: TextAlign.center,
                style: stampStyle(
                  color: LogbookTheme.faded(isDark),
                  size: 16,
                ),
              ),
              if (!isFiltered) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _openViewfinder,
                  icon: Icon(Icons.camera_alt, color: LogbookTheme.ink(isDark)),
                  label: Text(
                    'Open Viewfinder',
                    style: caveat(
                      size: 20,
                      weight: FontWeight.bold,
                      color: LogbookTheme.ink(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single "polaroid in a notebook" card.
class _PolaroidCard extends StatelessWidget {
  final LogEntry entry;
  final VoidCallback onTap;
  const _PolaroidCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Always keep the Polaroid card background white/light cream, even in dark mode.
    const cardColor = Color(0xFFFBF6E9);

    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(0),
            // Soft paper-shadow
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(1.5, 2.5),
                blurRadius: 5,
              ),
            ],
            border: Border.all(
              color: LogbookTheme.faded(false).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo with physical "Tape" look
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Hero(
                      tag: 'entry_image_${entry.id}',
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.file(
                          File(entry.imagePath),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          // Downscale decode for the thumbnail — big memory saving.
                          cacheWidth: 600,
                          errorBuilder: (ctx, error, stack) {
                            return Container(
                              color: Colors.black12,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: LogbookTheme.faded(false),
                                size: 40,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Decorative semi-transparent physical tape on top of the image
                  Positioned(
                    top: -12,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Container(
                          width: 55,
                          height: 15,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD2C8B4).withValues(alpha: 0.35),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 1,
                                offset: const Offset(0.5, 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            // Title (handwritten)
            Text(
              entry.title.trim().isEmpty
                  ? (entry.filmName ?? 'Untitled frame')
                  : entry.title.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: caveat(
                size: 22,
                weight: FontWeight.bold,
                color: LogbookTheme.ink(false),
              ),
            ),
            if (entry.note.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                entry.note.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: caveat(
                  size: 18,
                  color: LogbookTheme.faded(false),
                ),
              ),
            ],
            const SizedBox(height: 4),
            // Stamped settings line.
            Text(
              entry.roll != null && entry.roll!.trim().isNotEmpty
                  ? '${entry.roll!.toUpperCase()} · ${entry.settings}'
                  : entry.settings,
              style: stampStyle(
                color: LogbookTheme.faded(false),
                size: 15,
              ),
            ),
            const SizedBox(height: 2),
            // Date / place footer.
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 11,
                  color: LogbookTheme.faded(false),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(entry.createdAt),
                  style: stampStyle(
                    color: LogbookTheme.faded(false),
                    size: 14,
                  ),
                ),
                if (entry.placeName != null) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.place_outlined,
                    size: 11,
                    color: LogbookTheme.faded(false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.placeName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: stampStyle(
                        color: LogbookTheme.faded(false),
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

class _LogEntryContainer extends StatefulWidget {
  final LogEntry entry;
  final bool compactMode;
  final bool isDark;
  final VoidCallback onClosed;
  final void Function(VoidCallback triggerEdit) onLongPress;

  const _LogEntryContainer({
    required this.entry,
    required this.compactMode,
    required this.isDark,
    required this.onClosed,
    required this.onLongPress,
  });

  @override
  State<_LogEntryContainer> createState() => _LogEntryContainerState();
}

class _LogEntryContainerState extends State<_LogEntryContainer> {
  bool _startInEditMode = false;

  @override
  Widget build(BuildContext context) {
    final double rotateAngle = widget.compactMode
        ? 0.0
        : (((widget.entry.id.hashCode * 37) % 100) - 50) / 800; // rotation between -3.5 and +3.5 deg

    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fade,
      transitionDuration: const Duration(milliseconds: 600),
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      middleColor: Colors.transparent,
      openColor: LogbookTheme.paper(widget.isDark),
      clipBehavior: Clip.none,
      onClosed: (changed) {
        if (changed == true) {
          widget.onClosed();
        }
      },
      openBuilder: (context, action) {
        final edit = _startInEditMode;
        _startInEditMode = false;
        return LogDetailScreen(entry: widget.entry, startInEditMode: edit);
      },
      closedBuilder: (context, action) {
        final closedChild = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            widget.onLongPress(() {
              setState(() {
                _startInEditMode = true;
              });
              action();
            });
          },
          child: widget.compactMode
              ? _CompactListRow(
                  entry: widget.entry,
                  onTap: () {
                    precacheImage(
                      ResizeImage(FileImage(File(widget.entry.imagePath)), width: 1200),
                      context,
                    );
                    action();
                  },
                )
              : _PolaroidCard(
                  entry: widget.entry,
                  onTap: () {
                    precacheImage(
                      ResizeImage(FileImage(File(widget.entry.imagePath)), width: 1200),
                      context,
                    );
                    action();
                  },
                ),
        );

        if (rotateAngle == 0.0) {
          return closedChild;
        }

        return Transform.rotate(
          angle: rotateAngle,
          child: closedChild,
        );
      },
    );
  }
}

class _CompactListRow extends StatelessWidget {
  final LogEntry entry;
  final VoidCallback onTap;
  const _CompactListRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: LogbookTheme.faded(isDark).withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              offset: const Offset(1, 1.5),
              blurRadius: 3,
            ),
          ],
        ),
        child: CustomPaint(
          painter: LinedPaperPainter(
            lineColor: LogbookTheme.faded(isDark).withValues(alpha: 0.16),
            lineHeight: 22.0,
            offsetTop: 16.0,
          ),
          child: Row(
            children: [
              // Mini Polaroid styled photo frame with tape overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.rotate(
                    angle: -0.03, // slight tilt for skeuomorphic polaroid print feel
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                      decoration: BoxDecoration(
                        color: Colors.white, // stays white even in dark mode
                        border: Border.all(
                          color: LogbookTheme.faded(false).withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            offset: const Offset(1, 1.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'entry_image_${entry.id}',
                        child: SizedBox(
                          width: 64,
                          height: 52,
                          child: Image.file(
                            File(entry.imagePath),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 200,
                            errorBuilder: (ctx, error, stack) {
                              return Container(
                                color: Colors.black12,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: LogbookTheme.faded(false),
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Slanted washi tape over top of photo print
                  Positioned(
                    top: -8,
                    left: 12,
                    child: Transform.rotate(
                      angle: 0.08,
                      child: Container(
                        width: 32,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2C8B4).withValues(alpha: 0.35),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // EXIF Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.trim().isEmpty
                          ? (entry.filmName ?? 'Untitled frame')
                          : entry.title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caveat(
                        size: 20,
                        weight: FontWeight.bold,
                        color: LogbookTheme.ink(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.roll != null && entry.roll!.trim().isNotEmpty
                          ? '${entry.roll!.toUpperCase()} · ${entry.settings}'
                          : entry.settings,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: stampStyle(
                        color: LogbookTheme.faded(isDark),
                        size: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 9,
                          color: LogbookTheme.faded(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(entry.createdAt),
                          style: stampStyle(
                            color: LogbookTheme.faded(isDark),
                            size: 12,
                          ),
                        ),
                        if (entry.placeName != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.place_outlined,
                            size: 9,
                            color: LogbookTheme.faded(isDark),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              entry.placeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: stampStyle(
                                color: LogbookTheme.faded(isDark),
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: LogbookTheme.faded(isDark),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Folder color presets — completely independent of dark/light mode.
// ─────────────────────────────────────────────────────────────────────────────

/// Preset swatch colors for folder customization.
const List<int> kFolderColorPresets = [
  // Light / warm
  0xFFFDF8EC, // Warm cream (default look)
  0xFFF5EDE0, // Manila tan
  0xFFE8F0E5, // Sage green
  0xFFE5EBF5, // Dusty blue
  0xFFEDE5F5, // Lavender
  0xFFF5E5E8, // Dusty rose
  0xFFF0EAD2, // Warm sand
  // Dark
  0xFF2A2118, // Dark leather
  0xFF1A2818, // Dark forest
  0xFF181A28, // Dark navy
  0xFF281818, // Dark burgundy
];

/// Returns appropriate ink (text/icon) color for a given folder color.
Color folderInkFor(int colorValue) {
  final luminance = Color(colorValue).computeLuminance();
  return luminance > 0.35 ? const Color(0xFF2A2520) : Colors.white.withValues(alpha: 0.9);
}

/// Returns a subtle faded/secondary color for a folder.
Color folderFadedFor(int colorValue) {
  final luminance = Color(colorValue).computeLuminance();
  return luminance > 0.35
      ? const Color(0xFF2A2520).withValues(alpha: 0.45)
      : Colors.white.withValues(alpha: 0.45);
}

/// Builds a [LinearGradient] from a folder's base color.
LinearGradient folderGradientFor(int colorValue) {
  final base = Color(colorValue);
  final hsl = HSLColor.fromColor(base);
  final darker = hsl
      .withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0))
      .toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [base, darker],
  );
}

/// Color picker row widget used inside Create/Edit folder dialogs.
class _FolderColorPicker extends StatelessWidget {
  final int? selectedColor;
  final void Function(int? color) onColorSelected;

  const _FolderColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FOLDER COLOR',
          style: stampStyle(
            color: LogbookTheme.faded(Theme.of(context).brightness == Brightness.dark),
            size: 11,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // "Default" swatch (no custom color)
            GestureDetector(
              onTap: () => onColorSelected(null),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFDFBF0), Color(0xFFF7F1D5)],
                  ),
                  border: Border.all(
                    color: selectedColor == null
                        ? const Color(0xFF8A7E64)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                  ],
                ),
                child: selectedColor == null
                    ? const Icon(Icons.check, size: 16, color: Color(0xFF8A7E64))
                    : null,
              ),
            ),
            ...kFolderColorPresets.map((c) {
              final selected = selectedColor == c;
              return GestureDetector(
                onTap: () => onColorSelected(c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(c),
                    border: Border.all(
                      color: selected ? folderInkFor(c).withValues(alpha: 0.8) : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 4),
                    ],
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 16, color: folderInkFor(c))
                      : null,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  final LogFolder folder;
  final List<LogEntry> folderEntries;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isGrid;

  const _FolderCard({
    required this.folder,
    required this.folderEntries,
    required this.onTap,
    required this.onLongPress,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    // Folder color is ALWAYS the chosen color, independent of theme.
    final hasCustomColor = folder.colorValue != null;
    final folderGradient = hasCustomColor
        ? folderGradientFor(folder.colorValue!)
        : (Theme.of(context).brightness == Brightness.dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF383127), Color(0xFF2C261E)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFDFBF0), Color(0xFFF7F1D5)],
              ));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = hasCustomColor
        ? folderInkFor(folder.colorValue!)
        : LogbookTheme.ink(isDark);
    final fadedColor = hasCustomColor
        ? folderFadedFor(folder.colorValue!)
        : LogbookTheme.faded(isDark);
    final accentLabel = hasCustomColor
        ? folderFadedFor(folder.colorValue!)
        : (isDark ? const Color(0xFFA19277) : const Color(0xFF8A7E64));
    final borderSide = BorderSide(
      color: hasCustomColor
          ? folderInkFor(folder.colorValue!).withValues(alpha: 0.18)
          : (isDark
              ? const Color(0xFF4C4234).withValues(alpha: 0.5)
              : const Color(0xFFDED3B3).withValues(alpha: 0.8)),
      width: 1.5,
    );

    return Container(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isGrid ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Folder Tab top shape
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isGrid ? 12 : 16,
                    vertical: isGrid ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: folderGradient,
                    border: Border(
                      top: borderSide,
                      left: borderSide,
                      right: borderSide,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    'ARCHIVE',
                    style: stampStyle(
                      color: accentLabel,
                      size: isGrid ? 9 : 11,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: isGrid ? 19 : 23, // aligns with tab height + padding
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: borderSide,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Folder Main Body
            Expanded(
              flex: isGrid ? 1 : 0,
              child: Container(
                width: double.infinity,
                padding: isGrid
                    ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  gradient: folderGradient,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  border: Border(
                    left: borderSide,
                    right: borderSide,
                    bottom: borderSide,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      offset: const Offset(1, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: isGrid
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: caveat(
                              size: 21,
                              weight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${folderEntries.length} ${folderEntries.length == 1 ? "Frame" : "Frames"}',
                            style: stampStyle(
                              color: accentLabel,
                              size: 11,
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: SizedBox(
                              width: 80,
                              height: 60,
                              child: folderEntries.isEmpty
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.white24,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.folder_open,
                                        color: fadedColor.withValues(alpha: 0.3),
                                        size: 24,
                                      ),
                                    )
                                  : Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: List.generate(
                                        folderEntries.length > 3 ? 3 : folderEntries.length,
                                        (idx) {
                                          final entry = folderEntries[folderEntries.length - 1 - idx];
                                          double rot = (idx == 0) ? -0.05 : (idx == 1 ? 0.06 : -0.12);
                                          double offsetDx = (idx == 0) ? -6.0 : (idx == 1 ? 6.0 : 0.0);
                                          double offsetDy = (idx == 0) ? 3.0 : (idx == 1 ? -3.0 : 0.0);

                                          return Positioned(
                                            left: 8 + offsetDx,
                                            top: 8 + offsetDy,
                                            child: Transform.rotate(
                                              angle: rot,
                                              child: Container(
                                                padding: const EdgeInsets.fromLTRB(2, 2, 2, 5),
                                                decoration: BoxDecoration(
                                                  color: Colors.white, // stays white
                                                  border: Border.all(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    width: 0.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.12),
                                                      offset: const Offset(1, 1.5),
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: SizedBox(
                                                  width: 40,
                                                  height: 32,
                                                  child: Image.file(
                                                    File(entry.imagePath),
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 100,
                                                    errorBuilder: (ctx, error, stack) => Container(
                                                      color: Colors.black12,
                                                      child: Icon(
                                                        Icons.broken_image_outlined,
                                                        color: LogbookTheme.faded(false),
                                                        size: 12,
                                                      ),
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
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Folder text detail
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.name,
                                  style: caveat(
                                    size: 26,
                                    weight: FontWeight.bold,
                                    color: inkColor,
                                  ),
                                ),
                                if (folder.note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    folder.note,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: caveat(
                                      size: 18,
                                      color: fadedColor,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  '${folderEntries.length} ${folderEntries.length == 1 ? "Frame" : "Frames"}',
                                  style: stampStyle(
                                    color: accentLabel,
                                    size: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stacked miniature Polaroids
                          SizedBox(
                            width: 100,
                            height: 85,
                            child: folderEntries.isEmpty
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.folder_open,
                                      color: fadedColor.withValues(alpha: 0.3),
                                      size: 32,
                                    ),
                                  )
                                : Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: List.generate(
                                      folderEntries.length > 3 ? 3 : folderEntries.length,
                                      (idx) {
                                        final entry = folderEntries[folderEntries.length - 1 - idx];
                                        double rot = (idx == 0) ? -0.05 : (idx == 1 ? 0.06 : -0.12);
                                        double offsetDx = (idx == 0) ? -8.0 : (idx == 1 ? 8.0 : 0.0);
                                        double offsetDy = (idx == 0) ? 4.0 : (idx == 1 ? -4.0 : 0.0);

                                        return Positioned(
                                          left: 10 + offsetDx,
                                          top: 10 + offsetDy,
                                          child: Transform.rotate(
                                            angle: rot,
                                            child: Container(
                                              padding: const EdgeInsets.fromLTRB(3, 3, 3, 7),
                                              decoration: BoxDecoration(
                                                color: Colors.white, // stays white
                                                border: Border.all(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  width: 0.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.12),
                                                    offset: const Offset(1, 1.5),
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: SizedBox(
                                                width: 50,
                                                height: 42,
                                                child: Image.file(
                                                  File(entry.imagePath),
                                                  fit: BoxFit.cover,
                                                  cacheWidth: 100,
                                                  errorBuilder: (ctx, error, stack) => Container(
                                                    color: Colors.black12,
                                                    child: Icon(
                                                      Icons.broken_image_outlined,
                                                      color: LogbookTheme.faded(false),
                                                      size: 14,
                                                    ),
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
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFolderCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isGrid;

  const _CreateFolderCard({required this.onTap, this.isGrid = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = LogbookTheme.ink(isDark);
    final fadedColor = LogbookTheme.faded(isDark);

    return Container(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      child: DottedBorderWidget(
        color: fadedColor.withValues(alpha: 0.4),
        strokeWidth: 1.5,
        gap: 6.0,
        dashLength: 6.0,
        radius: 8.0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            height: isGrid ? double.infinity : null,
            padding: isGrid
                ? const EdgeInsets.symmetric(vertical: 16, horizontal: 12)
                : const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  color: inkColor,
                  size: isGrid ? 28 : 32,
                ),
                const SizedBox(height: 8),
                Text(
                  isGrid ? 'Create Folder' : 'Create New Archive Folder',
                  textAlign: TextAlign.center,
                  style: caveat(
                    size: isGrid ? 19 : 22,
                    weight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DottedBorderWidget extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double radius;

  const DottedBorderWidget({
    super.key,
    required this.child,
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 4.0,
    this.radius = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        gap: gap,
        dashLength: dashLength,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double radius;

  _DottedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dashLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (radius > 0) {
      path.addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
    } else {
      path.addRect(Offset.zero & size);
    }

    final dashPath = Path();
    for (final pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < pathMetric.length) {
        final length = draw ? dashLength : gap;
        if (draw) {
          dashPath.addPath(
            pathMetric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.radius != radius;
  }
}

// ── FolderDetailScreen ───────────────────────────────────────────────────────

class FolderDetailScreen extends StatefulWidget {
  final LogFolder folder;
  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  List<LogEntry> _entries = [];
  List<LogEntry> _sortedEntries = [];
  bool _loading = true;
  bool _compactMode = false;
  LogbookSortOrder _sortOrder = LogbookSortOrder.dateDescending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await LogbookStore.instance.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _entries = LogbookStore.instance.entries
          .where((e) => e.folderId == widget.folder.id)
          .toList();
      _loading = false;
      _compactMode = prefs.getBool('logbook_compact_mode') ?? false;
    });
    _updateSortedEntries();
  }

  void _updateSortedEntries() {
    final sorted = List<LogEntry>.from(_entries);
    if (_sortOrder == LogbookSortOrder.dateDescending) {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortOrder == LogbookSortOrder.dateAscending) {
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_sortOrder == LogbookSortOrder.titleAZ) {
      sorted.sort((a, b) {
        final titleA = a.title.trim().isEmpty ? (a.filmName ?? '') : a.title;
        final titleB = b.title.trim().isEmpty ? (b.filmName ?? '') : b.title;
        return titleA.toLowerCase().compareTo(titleB.toLowerCase());
      });
    }
    _sortedEntries = sorted;
  }

  void _openDetail(LogEntry entry, {bool startInEditMode = false}) async {
    // Pre-decode at detail-screen size (cacheWidth 1200) so Hero is smooth.
    precacheImage(
      ResizeImage(FileImage(File(entry.imagePath)), width: 1200),
      context,
    );
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LogDetailScreen(entry: entry, startInEditMode: startInEditMode)),
    );
    if (changed == true && mounted) _load();
  }

  void _showContextMenu(BuildContext context, LogEntry entry, Offset position, {VoidCallback? onEdit}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9);
    final inkColor = LogbookTheme.ink(isDark);

    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 30, 30),
        Offset.zero & overlay.size,
      ),
      color: paperColor,
      shape: Border.all(
        color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
        width: 1,
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: inkColor, size: 18),
              const SizedBox(width: 10),
              Text('Edit Details', style: caveat(size: 20, color: inkColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.folder_open_outlined, color: inkColor, size: 18),
              const SizedBox(width: 10),
              Text('Move to Folder', style: caveat(size: 20, color: inkColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: const Color(0xFFD46A6A), size: 18),
              const SizedBox(width: 10),
              Text('Delete Frame', style: caveat(size: 20, color: const Color(0xFFD46A6A))),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;
    if (selected == 'edit') {
      if (onEdit != null) {
        onEdit();
      } else {
        _openDetail(entry, startInEditMode: true);
      }
    } else if (selected == 'move') {
      _showMoveToFolderDialog(entry);
    } else if (selected == 'delete') {
      _confirmDelete(entry);
    }
  }

  void _showMoveToFolderDialog(LogEntry entry) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await LogbookStore.instance.ensureInitialized();
    final folders = LogbookStore.instance.folders;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final inkColor = LogbookTheme.ink(isDark);
        return AlertDialog(
          backgroundColor: LogbookTheme.paper(isDark),
          title: Text(
            'Move to Folder',
            style: caveat(size: 26, weight: FontWeight.bold, color: inkColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(Icons.folder_off_outlined, color: inkColor),
                  title: Text(
                    'No Folder (Unassign)',
                    style: caveat(size: 22, color: inkColor),
                  ),
                  onTap: () async {
                    await LogbookStore.instance.moveEntryToFolder(entry.id, null);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  },
                ),
                const Divider(height: 1),
                ...folders.map((folder) {
                  final isCurrent = entry.folderId == folder.id;
                  return ListTile(
                    leading: Icon(
                      isCurrent ? Icons.folder : Icons.folder_outlined,
                      color: isCurrent ? LogbookTheme.faded(isDark) : inkColor,
                    ),
                    title: Text(
                      folder.name,
                      style: caveat(
                        size: 22,
                        weight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: inkColor,
                      ),
                    ),
                    onTap: () async {
                      await LogbookStore.instance.moveEntryToFolder(entry.id, folder.id);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _load();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(LogEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This photo and its notes will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LogbookStore.instance.delete(entry.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme colors determined by folder custom color or default theme
    final hasCustomColor = widget.folder.colorValue != null;
    final folderGradient = hasCustomColor
        ? folderGradientFor(widget.folder.colorValue!)
        : (isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF383127), Color(0xFF2C261E)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFDFBF0), Color(0xFFF7F1D5)],
              ));
              
    final inkColor = hasCustomColor
        ? folderInkFor(widget.folder.colorValue!)
        : LogbookTheme.ink(isDark);
        
    return Hero(
      tag: 'folder_card_${widget.folder.id}',
      child: Container(
        decoration: BoxDecoration(
          gradient: folderGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent, // Let folderGradient show through
          body: SafeArea(
            child: Column(
              children: [
                buildBookHeader(
                  context,
                  widget.folder.name,
                  subtitle: widget.folder.note.trim().isNotEmpty
                      ? widget.folder.note
                      : 'Collection Archive',
                  actions: [
                    // Sort button
                    PopupMenuButton<LogbookSortOrder>(
                      icon: Icon(
                        Icons.sort,
                        color: inkColor,
                        size: 22,
                      ),
                      color: isDark ? const Color(0xFF241F18) : const Color(0xFFFBF6E9),
                      shape: Border.all(
                        color: LogbookTheme.faded(isDark).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      onSelected: (order) {
                        ExposureState.hapticLight();
                        setState(() {
                          _sortOrder = order;
                        });
                        _updateSortedEntries();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: LogbookSortOrder.dateDescending,
                          child: Text(
                            'Newest First',
                            style: caveat(
                              size: 20,
                              color: LogbookTheme.ink(isDark),
                              weight: _sortOrder == LogbookSortOrder.dateDescending ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: LogbookSortOrder.dateAscending,
                          child: Text(
                            'Oldest First',
                            style: caveat(
                              size: 20,
                              color: LogbookTheme.ink(isDark),
                              weight: _sortOrder == LogbookSortOrder.dateAscending ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: LogbookSortOrder.titleAZ,
                          child: Text(
                            'Title (A-Z)',
                            style: caveat(
                              size: 20,
                              color: LogbookTheme.ink(isDark),
                              weight: _sortOrder == LogbookSortOrder.titleAZ ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    // Compact/Grid switch
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        ExposureState.hapticLight();
                        final newVal = !_compactMode;
                        setState(() => _compactMode = newVal);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('logbook_compact_mode', newVal);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          _compactMode ? Icons.grid_view : Icons.view_list,
                          color: inkColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: _buildEntriesList(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntriesList(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 72,
                color: LogbookTheme.faded(isDark),
              ),
              const SizedBox(height: 16),
              Text(
                'Archive empty',
                style: caveat(
                  size: 30,
                  weight: FontWeight.bold,
                  color: LogbookTheme.ink(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Long press frames in the main list to move them to this archive.',
                textAlign: TextAlign.center,
                style: stampStyle(
                  color: LogbookTheme.faded(isDark),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      child: ListView.builder(
        key: ValueKey(_compactMode),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: _sortedEntries.length,
        itemBuilder: (context, i) {
          final entry = _sortedEntries[i];
          Offset tapPosition = Offset.zero;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              tapPosition = details.globalPosition;
            },
            child: _LogEntryContainer(
              entry: entry,
              compactMode: _compactMode,
              isDark: isDark,
              onClosed: () {
                if (mounted) _load();
              },
              onLongPress: (triggerEdit) {
                _showContextMenu(context, entry, tapPosition, onEdit: triggerEdit);
              },
            ),
          );
        },
      ),
    );
  }
}
