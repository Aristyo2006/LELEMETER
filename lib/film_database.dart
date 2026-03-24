enum FilmType {
  color_negative,
  black_white,
  slide,
  cine,
}

class FilmStock {
  final String name;
  final String brand;
  final FilmType type;
  final int iso;
  final double recommendedOverexposure;
  final bool pushable;

  const FilmStock({
    required this.name,
    required this.brand,
    required this.type,
    required this.iso,
    this.recommendedOverexposure = 0.0,
    this.pushable = false,
  });

  String get typeLabel {
    switch (type) {
      case FilmType.color_negative:
        return 'Color Negative';
      case FilmType.black_white:
        return 'B&W';
      case FilmType.slide:
        return 'Slide / Reversal';
      case FilmType.cine:
        return 'Cine / Motion';
    }
  }
}

class FilmDatabase {
  static const List<FilmStock> stocks = [
    FilmStock(name: "Kodak Portra 160", brand: "Kodak", type: FilmType.color_negative, iso: 160, recommendedOverexposure: 1),
    FilmStock(name: "Kodak Portra 400", brand: "Kodak", type: FilmType.color_negative, iso: 400, recommendedOverexposure: 1),
    FilmStock(name: "Kodak Portra 800", brand: "Kodak", type: FilmType.color_negative, iso: 800, recommendedOverexposure: 1),
    FilmStock(name: "Kodak Gold 200", brand: "Kodak", type: FilmType.color_negative, iso: 200, recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak UltraMax 400", brand: "Kodak", type: FilmType.color_negative, iso: 400, recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak ColorPlus 200", brand: "Kodak", type: FilmType.color_negative, iso: 200, recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak Pro Image 100", brand: "Kodak", type: FilmType.color_negative, iso: 100, recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak Ektar 100", brand: "Kodak", type: FilmType.color_negative, iso: 100, recommendedOverexposure: 0),

    FilmStock(name: "Fujifilm Superia 100", brand: "Fujifilm", type: FilmType.color_negative, iso: 100, recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Superia 200", brand: "Fujifilm", type: FilmType.color_negative, iso: 200, recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Superia X-TRA 400", brand: "Fujifilm", type: FilmType.color_negative, iso: 400, recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm C200", brand: "Fujifilm", type: FilmType.color_negative, iso: 200, recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Industrial 100", brand: "Fujifilm", type: FilmType.color_negative, iso: 100, recommendedOverexposure: 0.5),

    FilmStock(name: "Ilford HP5 Plus", brand: "Ilford", type: FilmType.black_white, iso: 400, pushable: true),
    FilmStock(name: "Ilford FP4 Plus", brand: "Ilford", type: FilmType.black_white, iso: 125),
    FilmStock(name: "Ilford Delta 100", brand: "Ilford", type: FilmType.black_white, iso: 100),
    FilmStock(name: "Ilford Delta 400", brand: "Ilford", type: FilmType.black_white, iso: 400),
    FilmStock(name: "Ilford Delta 3200", brand: "Ilford", type: FilmType.black_white, iso: 3200),
    FilmStock(name: "Kodak Tri-X 400", brand: "Kodak", type: FilmType.black_white, iso: 400, pushable: true),
    FilmStock(name: "Kodak T-Max 100", brand: "Kodak", type: FilmType.black_white, iso: 100),
    FilmStock(name: "Kodak T-Max 400", brand: "Kodak", type: FilmType.black_white, iso: 400),
    FilmStock(name: "Kentmere 100", brand: "Kentmere", type: FilmType.black_white, iso: 100),
    FilmStock(name: "Kentmere 400", brand: "Kentmere", type: FilmType.black_white, iso: 400),
    FilmStock(name: "Foma Fomapan 100", brand: "Foma", type: FilmType.black_white, iso: 100),
    FilmStock(name: "Foma Fomapan 200", brand: "Foma", type: FilmType.black_white, iso: 200),
    FilmStock(name: "Foma Fomapan 400", brand: "Foma", type: FilmType.black_white, iso: 400),

    FilmStock(name: "Fujifilm Velvia 50", brand: "Fujifilm", type: FilmType.slide, iso: 50),
    FilmStock(name: "Fujifilm Velvia 100", brand: "Fujifilm", type: FilmType.slide, iso: 100),
    FilmStock(name: "Fujifilm Provia 100F", brand: "Fujifilm", type: FilmType.slide, iso: 100),
    FilmStock(name: "Kodak Ektachrome E100", brand: "Kodak", type: FilmType.slide, iso: 100),
    FilmStock(name: "Agfa Precisa 100", brand: "Agfa", type: FilmType.slide, iso: 100),

    FilmStock(name: "Kodak Vision3 50D", brand: "Kodak", type: FilmType.cine, iso: 50),
    FilmStock(name: "Kodak Vision3 250D", brand: "Kodak", type: FilmType.cine, iso: 250),
    FilmStock(name: "Kodak Vision3 500T", brand: "Kodak", type: FilmType.cine, iso: 500),
    FilmStock(name: "CineStill 50D", brand: "CineStill", type: FilmType.cine, iso: 50),
    FilmStock(name: "CineStill 400D", brand: "CineStill", type: FilmType.cine, iso: 400),
    FilmStock(name: "CineStill 800T", brand: "CineStill", type: FilmType.cine, iso: 800),

    FilmStock(name: "Lomography Color 100", brand: "Lomography", type: FilmType.color_negative, iso: 100, recommendedOverexposure: 0.5),
    FilmStock(name: "Lomography Color 400", brand: "Lomography", type: FilmType.color_negative, iso: 400, recommendedOverexposure: 0.5),
    FilmStock(name: "Lomography Color 800", brand: "Lomography", type: FilmType.color_negative, iso: 800, recommendedOverexposure: 0.5),

    FilmStock(name: "Lomography Lady Grey 400", brand: "Lomography", type: FilmType.black_white, iso: 400),
    FilmStock(name: "Lomography Earl Grey 100", brand: "Lomography", type: FilmType.black_white, iso: 100),

    FilmStock(name: "Rollei Retro 80S", brand: "Rollei", type: FilmType.black_white, iso: 80),
    FilmStock(name: "Rollei Retro 400S", brand: "Rollei", type: FilmType.black_white, iso: 400),

    FilmStock(name: "Cinestill BwXX", brand: "CineStill", type: FilmType.black_white, iso: 250, pushable: true),
  ];
}
