enum FilmType {
  colorNegative,
  blackWhite,
  slide,
  cine,
}

class FilmStock {
  final String name;
  final String brand;
  final FilmType type;
  final int iso;
  final String desc;
  final double recommendedOverexposure;
  final bool pushable;

  const FilmStock({
    required this.name,
    required this.brand,
    required this.type,
    required this.iso,
    this.desc = '',
    this.recommendedOverexposure = 0.0,
    this.pushable = false,
  });

  String get typeLabel {
    switch (type) {
      case FilmType.colorNegative:
        return 'Color Negative';
      case FilmType.blackWhite:
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
    FilmStock(name: "Kodak Portra 160", brand: "Kodak", type: FilmType.colorNegative, iso: 160, desc: "A smooth portrait film with natural colors and fine detail.", recommendedOverexposure: 1),
    FilmStock(name: "Kodak Portra 400", brand: "Kodak", type: FilmType.colorNegative, iso: 400, desc: "A favorite among photographers, very forgiving with warm tones.", recommendedOverexposure: 1),
    FilmStock(name: "Kodak Portra 800", brand: "Kodak", type: FilmType.colorNegative, iso: 800, desc: "Great for low light with visible grain and a soft cinematic feel.", recommendedOverexposure: 1),
    FilmStock(name: "Kodak Gold 200", brand: "Kodak", type: FilmType.colorNegative, iso: 200, desc: "Classic warm tones with a nostalgic look, perfect for outdoor shooting.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak UltraMax 400", brand: "Kodak", type: FilmType.colorNegative, iso: 400, desc: "A reliable everyday film that performs well in many lighting conditions.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak ColorPlus 200", brand: "Kodak", type: FilmType.colorNegative, iso: 200, desc: "Affordable film with warm colors and a slightly vintage vibe.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak Pro Image 100", brand: "Kodak", type: FilmType.colorNegative, iso: 100, desc: "Clean and natural colors, best used in bright daylight.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak Ektar 100", brand: "Kodak", type: FilmType.colorNegative, iso: 100, desc: "Highly saturated colors with extremely fine grain, great for landscapes.", recommendedOverexposure: 0),

    FilmStock(name: "Fujifilm Superia 100", brand: "Fujifilm", type: FilmType.colorNegative, iso: 100, desc: "Cool tones with clean results.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Superia 200", brand: "Fujifilm", type: FilmType.colorNegative, iso: 200, desc: "Balanced colors with a slightly cool look.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Superia 400", brand: "Fujifilm", type: FilmType.colorNegative, iso: 400, desc: "Slightly contrasty with cool tones.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm 400H", brand: "Fujifilm", type: FilmType.colorNegative, iso: 400, desc: "Pro film with pastel tones and wide exposure latitude.", recommendedOverexposure: 1.0),
    FilmStock(name: "Agfa Vista 200", brand: "Agfa", type: FilmType.colorNegative, iso: 200, desc: "Saturated colors with high contrast.", recommendedOverexposure: 0.5),

    FilmStock(name: "Ilford HP 5 Plus 400", brand: "Ilford", type: FilmType.blackWhite, iso: 400, desc: "A flexible black and white film with classic grain.", pushable: true),
    FilmStock(name: "Ilford FP4 Plus", brand: "Ilford", type: FilmType.blackWhite, iso: 125, desc: "Fine grain with smooth tones, ideal for detail and controlled lighting."),
    FilmStock(name: "Ilford Delta 100", brand: "Ilford", type: FilmType.blackWhite, iso: 100, desc: "Very fine grain with a modern, sharp look."),
    FilmStock(name: "Ilford Delta 400", brand: "Ilford", type: FilmType.blackWhite, iso: 400, desc: "Balanced contrast and smooth grain for versatile shooting."),
    FilmStock(name: "Ilford Delta 3200", brand: "Ilford", type: FilmType.blackWhite, iso: 3200, desc: "Perfect for low light with strong grain."),
    FilmStock(name: "Polaroid 600", brand: "Polaroid", type: FilmType.colorNegative, iso: 640, desc: "Classic instant look with deep shadows."),
    FilmStock(name: "Polaroid 669", brand: "Polaroid", type: FilmType.colorNegative, iso: 80, desc: "Legendary peel-apart color film."),

    FilmStock(name: "Kodak Tri-X 400", brand: "Kodak", type: FilmType.blackWhite, iso: 400, desc: "Iconic black and white film with gritty grain and strong contrast.", pushable: true),
    FilmStock(name: "Kodak T-Max 100", brand: "Kodak", type: FilmType.blackWhite, iso: 100, desc: "Modern B&W film with fine grain and high detail."),
    FilmStock(name: "Kodak T-Max 400", brand: "Kodak", type: FilmType.blackWhite, iso: 400, desc: "Sharp and clean with a wide tonal range."),

    FilmStock(name: "Kentmere 100", brand: "Kentmere", type: FilmType.blackWhite, iso: 100, desc: "Budget-friendly film with clean detail and simple tones."),
    FilmStock(name: "Kentmere 400", brand: "Kentmere", type: FilmType.blackWhite, iso: 400, desc: "Affordable and versatile for everyday black and white shooting."),

    FilmStock(name: "Foma Fomapan 100", brand: "Foma", type: FilmType.blackWhite, iso: 100, desc: "Classic grain with a vintage look and soft contrast."),
    FilmStock(name: "Foma Fomapan 200", brand: "Foma", type: FilmType.blackWhite, iso: 200, desc: "Balanced grain and contrast with an old-school feel."),
    FilmStock(name: "Foma Fomapan 400", brand: "Foma", type: FilmType.blackWhite, iso: 400, desc: "Stronger contrast with a noticeable vintage character."),


    FilmStock(name: "Fujifilm Velvia 50", brand: "Fujifilm", type: FilmType.slide, iso: 50, desc: "Extremely vivid colors and high contrast, requires precise exposure."),
    FilmStock(name: "Fujifilm Velvia 100", brand: "Fujifilm", type: FilmType.slide, iso: 100, desc: "Bold colors with dramatic contrast, great for landscapes."),
    FilmStock(name: "Fujifilm Provia 100F", brand: "Fujifilm", type: FilmType.slide, iso: 100, desc: "More natural colors with better flexibility than Velvia."),
    FilmStock(name: "Kodak Ektachrome E100", brand: "Kodak", type: FilmType.slide, iso: 100, desc: "Clean and neutral colors with fine grain."),
    FilmStock(name: "Agfa Precisa 100", brand: "Agfa", type: FilmType.slide, iso: 100, desc: "Affordable slide film with vibrant tones."),

    FilmStock(name: "Kodak Vision3 50D", brand: "Kodak", type: FilmType.cine, iso: 50, desc: "Cinema film for daylight with extremely clean detail."),
    FilmStock(name: "Kodak Vision3 250D", brand: "Kodak", type: FilmType.cine, iso: 250, desc: "Balanced daylight film with wide dynamic range."),
    FilmStock(name: "Kodak Vision3 500T", brand: "Kodak", type: FilmType.cine, iso: 500, desc: "Low light cinema film with signature movie colors."),
    FilmStock(name: "CineStill 50D", brand: "CineStill", type: FilmType.cine, iso: 50, desc: "Daylight cinematic look adapted for photography."),
    FilmStock(name: "CineStill 400D", brand: "CineStill", type: FilmType.cine, iso: 400, desc: "Soft highlights with a cinematic daylight feel."),
    FilmStock(name: "CineStill 800T", brand: "CineStill", type: FilmType.cine, iso: 800, desc: "Night film with halation glow and cool blue tones."),

    FilmStock(name: "Lomography Color 100", brand: "Lomography", type: FilmType.colorNegative, iso: 100, desc: "Experimental film with unique colors and creative vibe.", recommendedOverexposure: 0.5),
    FilmStock(name: "Lomography Color 400", brand: "Lomography", type: FilmType.colorNegative, iso: 400, desc: "Unpredictable colors, great for creative shooting.", recommendedOverexposure: 0.5),
    FilmStock(name: "Lomography Color 800", brand: "Lomography", type: FilmType.colorNegative, iso: 800, desc: "Low light film with artistic and unique color shifts.", recommendedOverexposure: 0.5),

    FilmStock(name: "Lomography Lady Grey 400", brand: "Lomography", type: FilmType.blackWhite, iso: 400, desc: "Smooth tones with soft contrast."),
    FilmStock(name: "Lomography Earl Grey 100", brand: "Lomography", type: FilmType.blackWhite, iso: 100, desc: "Fine grain with gentle tonal rendering."),

    FilmStock(name: "Rollei Retro 80S", brand: "Rollei", type: FilmType.blackWhite, iso: 80, desc: "Technical film with high contrast and sharp detail."),
    FilmStock(name: "Rollei Retro 400S", brand: "Rollei", type: FilmType.blackWhite, iso: 400, desc: "Sharp and contrasty, good for bright conditions."),

    FilmStock(name: "Cinestill BwXX", brand: "CineStill", type: FilmType.blackWhite, iso: 250, desc: "Cinematic black and white with strong contrast.", pushable: true),

    FilmStock(name: "Lucky SHD 100", brand: "Lucky", type: FilmType.blackWhite, iso: 100, desc: "Simple film with fine detail and classic tones."),
    FilmStock(name: "Lucky SHD 200", brand: "Lucky", type: FilmType.blackWhite, iso: 200, desc: "Balanced grain and contrast for everyday use."),
    FilmStock(name: "Lucky SHD 400", brand: "Lucky", type: FilmType.blackWhite, iso: 400, desc: "Gritty grain with strong contrast, great for street.", pushable: true),
  ];
}
