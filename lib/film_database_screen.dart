import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exposure_state.dart';
import 'film_database.dart';
import 'ui_helpers.dart';

class FilmDatabaseScreen extends StatefulWidget {
  const FilmDatabaseScreen({super.key});

  @override
  State<FilmDatabaseScreen> createState() => _FilmDatabaseScreenState();
}

class _FilmDatabaseScreenState extends State<FilmDatabaseScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  FilmType? _activeFilter; // null = show all
  String? _activeBrandFilter; // null = show all brands
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Start animation shortly after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExposureState>();
    final primaryColor = state.primaryColor;
    final isDark = state.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : state.themeMode == ThemeMode.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final surfaceHigh =
        isDark ? const Color(0xFF1F2020) : const Color(0xFFF0F0F0);

    final filteredStocks = FilmDatabase.stocks.where((f) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = f.name.toLowerCase().contains(query) ||
          f.brand.toLowerCase().contains(query);
      final matchesFilter =
          _activeFilter == null || f.type == _activeFilter;
      final matchesBrand =
          _activeBrandFilter == null || f.brand == _activeBrandFilter;
      return matchesSearch && matchesFilter && matchesBrand;
    }).toList();

    // Group by brand
    final Map<String, List<FilmStock>> groupedStocks = {};
    for (var film in filteredStocks) {
      groupedStocks.putIfAbsent(film.brand, () => []).add(film);
    }
    final sortedBrands = groupedStocks.keys.toList()..sort();

    // Flatten sorted list for grid
    final sortedFilms = <FilmStock>[];
    for (final brand in sortedBrands) {
      sortedFilms.addAll(groupedStocks[brand]!);
    }

    final barHeight = 64 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ─── Content (First in Stack, so it sits behind the bar) ───────
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, barHeight + 16, 16, 100),
              children: [
                // Currently Loaded Banner
                _buildCurrentlyLoaded(state, primaryColor, isDark),
                const SizedBox(height: 20),

                // Search Bar
                _buildSearchBar(state, primaryColor, isDark, surfaceHigh),
                const SizedBox(height: 12),

                // Filter Buttons (by type)
                _buildFilterRow(state, primaryColor, isDark, surfaceHigh),
                const SizedBox(height: 8),

                // Brand Filter Row
                _buildBrandFilterRow(primaryColor, isDark),
                const SizedBox(height: 20),

                // Library Header
                Text(
                  'LIBRARY',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', 
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: isDark
                        ? const Color(0xFFACABAA)
                        : const Color(0xFF767575),
                  ),
                ),
                const SizedBox(height: 12),

                // Film Shelf
                sortedFilms.isEmpty
                    ? _buildEmptyState(primaryColor)
                    : _buildShelf(context, groupedStocks, sortedBrands, state, primaryColor, isDark),
              ],
            ),
          ),

          // ─── Top App Bar (Second in Stack, so it overlays the content) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context, state, primaryColor, isDark, surfaceHigh),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ExposureState state,
    Color primaryColor,
    bool isDark,
    Color surfaceHigh,
  ) {
    return ClipRect(
      child: state.enableBlur
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: _buildTopBarContent(context, state, isDark, surfaceHigh),
            )
          : _buildTopBarContent(context, state, isDark, surfaceHigh),
    );
  }

  Widget _buildTopBarContent(
    BuildContext context,
    ExposureState state,
    bool isDark,
    Color surfaceHigh,
  ) {
    return Container(
          height: 64 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1F2020) : surfaceHigh)
                .withValues(alpha: state.enableBlur ? 0.82 : 1.0),
            image: skeuomorphicNoise,
            border: Border(
              bottom: BorderSide(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Back Button (Aligned Left)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2B2C2C)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(1.5, 2.5),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.08),
                          blurRadius: 1,
                          offset: const Offset(-0.5, -0.5),
                          blurStyle: BlurStyle.inner,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white70 : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Absolute Centered Title
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_roll,
                      color: state.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FILM STOCK',
                      style: TextStyle(fontFamily: 'SpaceGrotesk', 
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildCurrentlyLoaded(
    ExposureState state,
    Color primaryColor,
    bool isDark,
  ) {
    final film = state.selectedFilm;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF3A3C3C), const Color(0xFF1F2020)]
              : [const Color(0xFFEEEEEE), const Color(0xFFE0E0E0)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? const Color(0xFF484848).withValues(alpha: 0.3)
              : const Color(0xFFCCCCCC),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.8 : 0.15),
            blurRadius: 4,
            offset: const Offset(2, 2),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.6),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'CURRENTLY LOADED',
            style: TextStyle(fontFamily: 'SpaceGrotesk', 
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: isDark
                  ? const Color(0xFFACABAA)
                  : const Color(0xFF767575),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            film != null ? film.name.toUpperCase() : '--- NO FILM ---',
            style: TextStyle(fontFamily: 'SpaceGrotesk', 
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: film != null ? primaryColor : const Color(0xFF767575),
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          if (film != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ISO ${film.iso}',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', 
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFACABAA)
                        : const Color(0xFF767575),
                    letterSpacing: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '•',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF484848)
                          : const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
                Text(
                  film.typeLabel.toUpperCase(),
                  style: TextStyle(fontFamily: 'SpaceGrotesk', 
                    fontSize: 11,
                    color: _getTypeColor(film.type),
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            Text(
              'SELECT A FILM BELOW',
              style: TextStyle(fontFamily: 'SpaceGrotesk', 
                fontSize: 11,
                color: isDark
                    ? const Color(0xFF767575)
                    : const Color(0xFFACABAA),
                letterSpacing: 1,
              ),
            ),
          if (film != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => state.selectFilm(null),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  'UNLOAD',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', 
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: isDark
                        ? const Color(0xFFACABAA)
                        : const Color(0xFF767575),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    ExposureState state,
    Color primaryColor,
    bool isDark,
    Color surfaceHigh,
  ) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark
              ? const Color(0xFF484848)
              : const Color(0xFFCCCCCC),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 4,
            offset: const Offset(2, 2),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(fontFamily: 'SpaceGrotesk', 
          color: isDark ? Colors.white : Colors.black,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'Search film stock...',
          hintStyle: TextStyle(fontFamily: 'SpaceGrotesk', 
            color: isDark
                ? const Color(0xFF767575)
                : const Color(0xFFACABAA),
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF767575)
                        : const Color(0xFFACABAA),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterRow(
    ExposureState state,
    Color primaryColor,
    bool isDark,
    Color surfaceHigh,
  ) {
    final filters = [
      (label: 'ALL', type: null, icon: Icons.grid_view),
      (label: 'NEGATIVE', type: FilmType.color_negative, icon: Icons.camera_alt_outlined),
      (label: 'B&W', type: FilmType.black_white, icon: Icons.contrast),
      (label: 'SLIDE', type: FilmType.slide, icon: Icons.filter_vintage),
      (label: 'CINE', type: FilmType.cine, icon: Icons.movie_filter_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _activeFilter == f.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = f.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withValues(alpha: 0.9),
                            primaryColor.withValues(alpha: 0.6),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  const Color(0xFF2B2C2C),
                                  const Color(0xFF191A1A),
                                ]
                              : [
                                  const Color(0xFFFFFFFF),
                                  const Color(0xFFE5E5E5),
                                ],
                        ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? primaryColor.withValues(alpha: 0.5)
                        : (isDark
                            ? const Color(0xFF484848)
                            : const Color(0xFFD4D4D4)),
                    width: 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                            blurStyle: BlurStyle.inner,
                          ),
                        ]
                      : isDark ? [
                          // Hard bottom shadow - lifts button off surface
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            blurRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                          // Soft depth blur
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4,
                            offset: const Offset(1.5, 3.5),
                          ),
                          // Top highlight: simulates light catching the top rim
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.12),
                            blurRadius: 1,
                            offset: const Offset(0, -0.5),
                            blurStyle: BlurStyle.inner,
                          ),
                        ] : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      f.icon,
                      size: 13,
                      color: isActive
                          ? Colors.black
                          : (isDark
                              ? const Color(0xFFACABAA)
                              : const Color(0xFF767575)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isActive
                            ? Colors.black
                            : (isDark
                                ? const Color(0xFFACABAA)
                                : const Color(0xFF767575)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Shelf Layout ───────────────────────────────────────────────────────────

  Widget _buildShelf(
    BuildContext context,
    Map<String, List<FilmStock>> grouped,
    List<String> brands,
    ExposureState state,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: brands.map((brand) {
        final films = grouped[brand]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: _buildShelfRow(
            context,
            brand,
            films,
            state,
            primaryColor,
            isDark,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShelfRow(
    BuildContext context,
    String brand,
    List<FilmStock> films,
    ExposureState state,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            brand.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Color(0xFFACABAA),
            ),
          ),
        ),
        // Shelf section: films + wooden plank
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Wooden shelf back wall (full area)
            Container(
              height: 210,
              decoration: BoxDecoration(
                image: skeuomorphicNoise,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFB5742B),
                    Color(0xFF9A5F1F),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 6),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _WoodGrainPainter(),
                child: Container(),
              ),
            ),
            // Film spines row
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                itemCount: films.length,
                itemBuilder: (context, index) {
                  final delay = index * 0.08;
                  final animation = CurvedAnimation(
                    parent: _entranceController,
                    curve: Interval(delay.clamp(0.0, 0.8), (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutBack),
                  );
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 40 * (1 - animation.value)),
                        child: Opacity(
                          opacity: animation.value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilmSpine(context, films[index], state, primaryColor, isDark),
                    ),
                  );
                },
              ),
            ),
            // Shelf plank (bottom edge lip)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF7A4210),
                      Color(0xFF5C2F08),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilmSpine(
    BuildContext context,
    FilmStock film,
    ExposureState state,
    Color primaryColor,
    bool isDark,
  ) {
    final isSelected = state.selectedFilm?.name == film.name;
    // final isDark = state.themeMode == ThemeMode.dark; // This line was redundant as isDark is passed in

    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () {
            state.selectFilm(film);
            Navigator.pop(context);
          },
          onLongPressStart: (d) {
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            final Offset position = box?.localToGlobal(Offset.zero) ?? Offset.zero;
            final spineRect = position & (box?.size ?? Size.zero);
            _showFilmDetail(context, film, state, primaryColor, d.globalPosition, spineRect, isDark);
          },
          child: _buildSpineVisuals(film, state, isDark, primaryColor, isSelected),
        );
      },
    );
  }

  Widget _buildSpineVisuals(
    FilmStock film,
    ExposureState state,
    bool isDark,
    Color primaryColor,
    bool isSelected, {
    bool isHighlighted = false,
  }) {
    final spineColor = _getSpineColor(film.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 90,
      transform: (isSelected && !isHighlighted)
          ? Matrix4.translationValues(0, -8, 0)
          : Matrix4.identity(),
        decoration: BoxDecoration(
          color: spineColor,
          image: skeuomorphicNoise,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : Colors.black.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.7),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(2, 3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Top color stripe
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Film type icon (small)
                    Opacity(
                      opacity: 0.7,
                      child: _getFilmIconWidget(film.type, size: 20),
                    ),
                    const SizedBox(height: 6),
                    // ISO badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '${film.iso}',
                        style: const TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Film name — rotated, auto-shrinks to fit, no cutoff
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            film.name.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Selected dot
                    if (isSelected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }

  void _showFilmDetail(
    BuildContext context,
    FilmStock film,
    ExposureState state,
    Color primaryColor,
    Offset tapPosition,
    Rect spineRect,
    bool isDark, // Added isDark parameter
  ) {
    // final isDark = state.themeMode == ThemeMode.dark; // This line was redundant
    final typeColor = _getTypeColor(film.type);
    final spineColor = _getSpineColor(film.type);
    const cardWidth = 260.0;
    const arrowH = 14.0;
    const margin = 12.0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(curved),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) {
        final screen = MediaQuery.of(context).size;
        // Center callout horizontally on the spine
        final targetX = spineRect.center.dx;
        final targetY = spineRect.top;

        double left = targetX - cardWidth / 2;
        left = left.clamp(margin, screen.width - cardWidth - margin);

        // Arrow points at the center of the spine
        final arrowRelX = ((targetX - left) / cardWidth).clamp(0.15, 0.85);

        // 4px gap above/below target
        final arrowOnBottom = targetY > (screen.height / 2);

        return Stack(
          children: [
            // Blurred backdrop — tap to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: state.enableBlur
                    ? BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.black.withValues(alpha: 0.35)),
                      )
                    : Container(color: Colors.black.withValues(alpha: 0.9)),
              ),
            ),
            // "Punch-through" spine duplicate (stays sharp)
            Positioned.fromRect(
              rect: spineRect,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 1.04, // Slightly pop to show highlight
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _buildSpineVisuals(
                      film,
                      state,
                      isDark,
                      primaryColor,
                      state.selectedFilm?.name == film.name,
                      isHighlighted: true,
                    ),
                  ),
                ),
              ),
            ),
            // Callout bubble (bottom-anchored if above)
            Positioned(
              left: left,
              top: arrowOnBottom ? null : targetY + spineRect.height + 4,
              bottom: arrowOnBottom ? screen.height - targetY + 4 : null,
              width: cardWidth,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!arrowOnBottom)
                      CustomPaint(
                        size: Size(cardWidth, arrowH),
                        painter: _CalloutArrowPainter(
                          arrowRelX: arrowRelX,
                          color: isDark ? const Color(0xFF1A1B1B) : Colors.white,
                          borderColor: primaryColor.withValues(alpha: 0.4),
                          pointDown: false,
                        ),
                      ),
                    // Card body
                    Container(
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1A1B1B) : Colors.white)
                            .withValues(alpha: 0.96),
                        image: skeuomorphicNoise,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: spineColor.withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: spineColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: spineColor.withValues(alpha: 0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: _getFilmIconWidget(film.type, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      film.name.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      film.brand.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 9,
                                        letterSpacing: 1.5,
                                        color: Color(0xFFACABAA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildStatChip('ISO', '${film.iso}', typeColor),
                              _buildStatChip('TYPE', _getShortTypeLabel(film.type), typeColor),
                              if (film.pushable)
                                _buildStatChip('PUSH', 'YES', const Color(0xFF8EFF71)),
                              if (film.recommendedOverexposure > 0)
                                _buildStatChip('EXP', '+${film.recommendedOverexposure.toStringAsFixed(1)}', const Color(0xFFFFCD62)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (film.desc.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                film.desc,
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 10,
                                  height: 1.4,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: () {
                              state.selectFilm(film);
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'LOAD FILM',
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (arrowOnBottom)
                      CustomPaint(
                        size: Size(cardWidth, arrowH),
                        painter: _CalloutArrowPainter(
                          arrowRelX: arrowRelX,
                          color: isDark ? const Color(0xFF1A1B1B) : Colors.white,
                          borderColor: primaryColor.withValues(alpha: 0.4),
                          pointDown: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 8,
              letterSpacing: 1.5,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpineColor(FilmType type) {
    switch (type) {
      case FilmType.color_negative:
        return const Color(0xFF1A3A5C);
      case FilmType.black_white:
        return const Color(0xFF2A2A2A);
      case FilmType.slide:
        return const Color(0xFF1A4A28);
      case FilmType.cine:
        return const Color(0xFF4A1A1A);
    }
  }

  Widget _buildBrandFilterRow(Color primaryColor, bool isDark) {
    // Collect unique brands dynamically, sorted alphabetically
    final brands = FilmDatabase.stocks
        .map((f) => f.brand)
        .toSet()
        .toList()
      ..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "ALL" chip
          _buildBrandChip(
            label: 'ALL',
            isActive: _activeBrandFilter == null,
            primaryColor: primaryColor,
            isDark: isDark,
            onTap: () => setState(() => _activeBrandFilter = null),
          ),
          ...brands.map(
            (brand) => _buildBrandChip(
              label: brand.toUpperCase(),
              isActive: _activeBrandFilter == brand,
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () => setState(
                () => _activeBrandFilter =
                    _activeBrandFilter == brand ? null : brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandChip({
    required String label,
    required bool isActive,
    required Color primaryColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? primaryColor.withValues(alpha: 0.15)
                : (isDark
                    ? const Color(0xFF191A1A)
                    : const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.7)
                  : (isDark
                      ? const Color(0xFF3A3C3C)
                      : const Color(0xFFCCCCCC)),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.9 : 0.2),
                      blurRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                      blurRadius: 3,
                      offset: const Offset(1, 2.5),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.8),
                      blurRadius: 1,
                      offset: const Offset(0, -0.5),
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(fontFamily: 'SpaceGrotesk', 
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isActive
                  ? primaryColor
                  : (isDark
                      ? const Color(0xFF9D9E9E)
                      : const Color(0xFF767575)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.camera_roll_outlined,
            color: primaryColor.withValues(alpha: 0.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'NO FILM STOCKS FOUND',
            style: TextStyle(fontFamily: 'SpaceGrotesk', 
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: const Color(0xFF767575),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(FilmType type) {
    switch (type) {
      case FilmType.color_negative:
        return const Color(0xFFFFB300);
      case FilmType.black_white:
        return const Color(0xFFACABAA);
      case FilmType.slide:
        return const Color(0xFF3DB832); // darker green - readable on light bg
      case FilmType.cine:
        return const Color(0xFFEE7D77);
    }
  }



  Widget _getFilmIconWidget(FilmType type, {double size = 40}) {
    switch (type) {
      case FilmType.color_negative:
        return SvgPicture.asset(
          'assets/Film.svg',
          width: size,
          height: size,
          colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
      case FilmType.slide:
        return SvgPicture.asset(
          'assets/Slide.svg',
          width: size,
          height: size,
          colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
      case FilmType.black_white:
        return Icon(Icons.contrast, size: size, color: Colors.white);
      case FilmType.cine:
        return Icon(Icons.movie_filter, size: size, color: Colors.white);
    }
  }

  String _getShortTypeLabel(FilmType type) {
    switch (type) {
      case FilmType.color_negative:
        return 'NEG';
      case FilmType.black_white:
        return 'B&W';
      case FilmType.slide:
        return 'SLIDE';
      case FilmType.cine:
        return 'CINE';
    }
  }
}

// Wooden grain painter for shelf backing
class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final grains = [
      const Color(0xFFD4882A),
      const Color(0xFFBE7520),
      const Color(0xFFCF8030),
    ];
    for (int i = 0; i < 20; i++) {
      paint.color = grains[i % grains.length].withValues(alpha: 0.2);
      final y = (size.height / 20) * i;
      final path = Path();
      path.moveTo(0, y);
      for (double x = 0; x < size.width; x += 30) {
        path.cubicTo(x + 10, y - 3, x + 20, y + 3, x + 30, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter oldDelegate) => false;
}



// iOS-style callout arrow / speech bubble triangle pointer
class _CalloutArrowPainter extends CustomPainter {
  final double arrowRelX;
  final Color color;
  final Color borderColor;
  final bool pointDown;

  const _CalloutArrowPainter({
    required this.arrowRelX,
    required this.color,
    required this.borderColor,
    required this.pointDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arrowX = size.width * arrowRelX;
    const arrowW = 18.0;
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final path = Path();
    if (pointDown) {
      path.moveTo(arrowX - arrowW / 2, 0);
      path.lineTo(arrowX + arrowW / 2, 0);
      path.lineTo(arrowX, size.height);
      path.close();
    } else {
      path.moveTo(arrowX - arrowW / 2, size.height);
      path.lineTo(arrowX + arrowW / 2, size.height);
      path.lineTo(arrowX, 0);
      path.close();
    }
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_CalloutArrowPainter old) =>
      old.arrowRelX != arrowRelX || old.pointDown != pointDown;
}
