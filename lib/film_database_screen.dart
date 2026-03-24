import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exposure_state.dart';
import 'film_database.dart';

class FilmDatabaseScreen extends StatefulWidget {
  const FilmDatabaseScreen({super.key});

  @override
  State<FilmDatabaseScreen> createState() => _FilmDatabaseScreenState();
}

class _FilmDatabaseScreenState extends State<FilmDatabaseScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  FilmType? _activeFilter; // null = show all
  String? _activeBrandFilter; // null = show all brands

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExposureState>();
    final primaryColor = state.primaryColor;
    final isDark = state.themeMode == ThemeMode.dark;
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // ─── Top App Bar ───────────────────────────────────────────────
          _buildTopBar(context, primaryColor, isDark, surfaceHigh),

          // ─── Content ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: isDark
                        ? const Color(0xFFACABAA)
                        : const Color(0xFF767575),
                  ),
                ),
                const SizedBox(height: 12),

                // Film Grid
                sortedFilms.isEmpty
                    ? _buildEmptyState(primaryColor)
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: sortedFilms.length,
                        itemBuilder: (context, index) {
                          return _buildFilmCard(
                            context,
                            sortedFilms[index],
                            state,
                            primaryColor,
                            isDark,
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Color primaryColor,
    bool isDark,
    Color surfaceHigh,
  ) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2020) : surfaceHigh,
        border: isDark
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
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
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.camera_roll,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'FILM STOCK',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 56),
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
            style: GoogleFonts.spaceGrotesk(
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
            style: GoogleFonts.spaceGrotesk(
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
                  style: GoogleFonts.spaceGrotesk(
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
                  style: GoogleFonts.spaceGrotesk(
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
              style: GoogleFonts.spaceGrotesk(
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
                  style: GoogleFonts.spaceGrotesk(
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
        style: GoogleFonts.spaceGrotesk(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'Search film stock...',
          hintStyle: GoogleFonts.spaceGrotesk(
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
                      style: GoogleFonts.spaceGrotesk(
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

  Widget _buildFilmCard(
    BuildContext context,
    FilmStock film,
    ExposureState state,
    Color primaryColor,
    bool isDark,
  ) {
    final isSelected = state.selectedFilm?.name == film.name;
    final typeColor = _getTypeColor(film.type);

    return GestureDetector(
      onTap: () {
        state.selectFilm(film);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131313) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.8)
                : (isDark ? const Color(0xFF252626) : const Color(0xFFEEEEEE)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 0,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.7),
              blurRadius: 1,
              offset: const Offset(0, 1),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Film thumbnail / color swatch area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getFilmGradient(film.type, isDark),
                  ),
                ),
                child: Stack(
                  children: [
                    // Grain texture overlay
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.5,
                        child: CustomPaint(
                          painter: _MiniGrainPainter(
                            seed: film.name.hashCode,
                            color: _getFilmGradient(film.type, isDark).last,
                          ),
                        ),
                      ),
                    ),
                    // Film type icon center
                    Center(
                      child: Opacity(
                        opacity: 0.25,
                        child: _getFilmIconWidget(film.type, size: 40),
                      ),
                    ),
                    // ISO badge top left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'ISO ${film.iso}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    // Selected dot
                    if (isSelected)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 10,
                          height: 10,
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
                      ),
                    // EXP badge bottom-left
                    if (film.recommendedOverexposure > 0)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'EXP +${film.recommendedOverexposure.toStringAsFixed(1)}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFCD62),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    // Pushable badge
                    if (film.pushable)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                primaryColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'PUSH',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    // Bottom gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              isDark
                                  ? Colors.black.withValues(alpha: 0.7)
                                  : Colors.black.withValues(alpha: 0.15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Card footer
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    film.name.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white : Colors.black),
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        film.brand,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          color: isDark
                              ? const Color(0xFF767575)
                              : const Color(0xFFACABAA),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _getShortTypeLabel(film.type),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            style: GoogleFonts.spaceGrotesk(
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
            style: GoogleFonts.spaceGrotesk(
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

  List<Color> _getFilmGradient(FilmType type, bool isDark) {
    switch (type) {
      case FilmType.color_negative:
        return isDark
            ? [const Color(0xFF2C2000), const Color(0xFF1A1200)]
            : [const Color(0xFFFFF8E0), const Color(0xFFFFF0B0)];
      case FilmType.black_white:
        return isDark
            ? [const Color(0xFF252626), const Color(0xFF131313)]
            : [const Color(0xFFEEEEEE), const Color(0xFFD0D0D0)];
      case FilmType.slide:
        return isDark
            ? [const Color(0xFF0B2000), const Color(0xFF071400)]
            : [const Color(0xFFE8FFE0), const Color(0xFFD0F8C0)];
      case FilmType.cine:
        return isDark
            ? [const Color(0xFF2C0A08), const Color(0xFF1A0505)]
            : [const Color(0xFFFFEEEC), const Color(0xFFFFD8D4)];
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

// Micro grain painter for cards
class _MiniGrainPainter extends CustomPainter {
  final int seed;
  final Color color;
  _MiniGrainPainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = seed.hashCode;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = 0; i < 150; i++) {
      final x = ((rng * (i * 7 + 1)) % size.width.toInt()).abs().toDouble();
      final y = ((rng * (i * 13 + 3)) % size.height.toInt()).abs().toDouble();
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
    }
  }

  @override
  bool shouldRepaint(_MiniGrainPainter oldDelegate) => false;
}
