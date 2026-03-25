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
    FilmStock(name: "Kodak Portra 160", brand: "Kodak", type: FilmType.color_negative, iso: 160, desc: "A smooth portrait film with natural colors and fine detail, perfect for bright daylight.", recommendedOverexposure: 1),
    FilmStock(name: "Kodak Portra 400", brand: "Kodak", type: FilmType.color_negative, iso: 400, desc: "A favorite among photographers, very forgiving with warm tones and flexible exposure.", recommendedOverexposure: 1),
    FilmStock(name: "Kodak Portra 800", brand: "Kodak", type: FilmType.color_negative, iso: 800, desc: "Great for low light with visible grain and a soft cinematic feel.", recommendedOverexposure: 1),
    FilmStock(name: "Kodak Gold 200", brand: "Kodak", type: FilmType.color_negative, iso: 200, desc: "Classic warm tones with a nostalgic look, perfect for outdoor shooting.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak UltraMax 400", brand: "Kodak", type: FilmType.color_negative, iso: 400, desc: "A reliable everyday film that performs well in many lighting conditions.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak ColorPlus 200", brand: "Kodak", type: FilmType.color_negative, iso: 200, desc: "Affordable film with warm colors and a slightly vintage vibe.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak Pro Image 100", brand: "Kodak", type: FilmType.color_negative, iso: 100, desc: "Clean and natural colors, best used in bright daylight.", recommendedOverexposure: 0.5),
    FilmStock(name: "Kodak Ektar 100", brand: "Kodak", type: FilmType.color_negative, iso: 100, desc: "Highly saturated colors with extremely fine grain, great for landscapes.", recommendedOverexposure: 0),

    FilmStock(name: "Fujifilm Superia 100", brand: "Fujifilm", type: FilmType.color_negative, iso: 100, desc: "Cool tones with clean results, ideal for daylight photography.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Superia 200", brand: "Fujifilm", type: FilmType.color_negative, iso: 200, desc: "Balanced colors with a slightly cool look, great for everyday use.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Superia X-TRA 400", brand: "Fujifilm", type: FilmType.color_negative, iso: 400, desc: "Slightly contrasty with cool tones, works well in mixed lighting.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm C200", brand: "Fujifilm", type: FilmType.color_negative, iso: 200, desc: "Simple and clean film with neutral colors for casual shooting.", recommendedOverexposure: 0.5),
    FilmStock(name: "Fujifilm Industrial 100", brand: "Fujifilm", type: FilmType.color_negative, iso: 100, desc: "Neutral color rendering with consistent and clean results.", recommendedOverexposure: 0.5),

    FilmStock(name: "Ilford HP5 Plus", brand: "Ilford", type: FilmType.black_white, iso: 400, desc: "A flexible black and white film with classic grain, great for street and pushing.", pushable: true),
    FilmStock(name: "Ilford FP4 Plus", brand: "Ilford", type: FilmType.black_white, iso: 125, desc: "Fine grain with smooth tones, ideal for detail and controlled lighting."),
    FilmStock(name: "Ilford Delta 100", brand: "Ilford", type: FilmType.black_white, iso: 100, desc: "Very fine grain with a modern, sharp look."),
    FilmStock(name: "Ilford Delta 400", brand: "Ilford", type: FilmType.black_white, iso: 400, desc: "Balanced contrast and smooth grain for versatile shooting."),
    FilmStock(name: "Ilford Delta 3200", brand: "Ilford", type: FilmType.black_white, iso: 3200, desc: "Perfect for low light with strong grain and dramatic contrast."),

    FilmStock(name: "Kodak Tri-X 400", brand: "Kodak", type: FilmType.black_white, iso: 400, desc: "Iconic black and white film with gritty grain and strong contrast.", pushable: true),
    FilmStock(name: "Kodak T-Max 100", brand: "Kodak", type: FilmType.black_white, iso: 100, desc: "Modern B&W film with fine grain and high detail."),
    FilmStock(name: "Kodak T-Max 400", brand: "Kodak", type: FilmType.black_white, iso: 400, desc: "Sharp and clean with a wide tonal range."),

    FilmStock(name: "Kentmere 100", brand: "Kentmere", type: FilmType.black_white, iso: 100, desc: "Budget-friendly film with clean detail and simple tones."),
    FilmStock(name: "Kentmere 400", brand: "Kentmere", type: FilmType.black_white, iso: 400, desc: "Affordable and versatile for everyday black and white shooting."),

    FilmStock(name: "Foma Fomapan 100", brand: "Foma", type: FilmType.black_white, iso: 100, desc: "Classic grain with a vintage look and soft contrast."),
    FilmStock(name: "Foma Fomapan 200", brand: "Foma", type: FilmType.black_white, iso: 200, desc: "Balanced grain and contrast with an old-school feel."),
    FilmStock(name: "Foma Fomapan 400", brand: "Foma", type: FilmType.black_white, iso: 400, desc: "Stronger contrast with a noticeable vintage character."),

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

    FilmStock(name: "Lomography Color 100", brand: "Lomography", type: FilmType.color_negative, iso: 100, desc: "Experimental film with unique colors and creative vibe.", recommendedOverexposure: 0.5),
    FilmStock(name: "Lomography Color 400", brand: "Lomography", type: FilmType.color_negative, iso: 400, desc: "Unpredictable colors, great for creative shooting.", recommendedOverexposure: 0.5),
    FilmStock(name: "Lomography Color 800", brand: "Lomography", type: FilmType.color_negative, iso: 800, desc: "Low light film with artistic and unique color shifts.", recommendedOverexposure: 0.5),

    FilmStock(name: "Lomography Lady Grey 400", brand: "Lomography", type: FilmType.black_white, iso: 400, desc: "Smooth tones with soft contrast."),
    FilmStock(name: "Lomography Earl Grey 100", brand: "Lomography", type: FilmType.black_white, iso: 100, desc: "Fine grain with gentle tonal rendering."),

    FilmStock(name: "Rollei Retro 80S", brand: "Rollei", type: FilmType.black_white, iso: 80, desc: "Technical film with high contrast and sharp detail."),
    FilmStock(name: "Rollei Retro 400S", brand: "Rollei", type: FilmType.black_white, iso: 400, desc: "Sharp and contrasty, good for bright conditions."),

    FilmStock(name: "Cinestill BwXX", brand: "CineStill", type: FilmType.black_white, iso: 250, desc: "Cinematic black and white with strong contrast.", pushable: true),

    FilmStock(name: "Lucky SHD 100", brand: "Lucky", type: FilmType.black_white, iso: 100, desc: "Simple film with fine detail and classic tones."),
    FilmStock(name: "Lucky SHD 200", brand: "Lucky", type: FilmType.black_white, iso: 200, desc: "Balanced grain and contrast for everyday use."),
    FilmStock(name: "Lucky SHD 400", brand: "Lucky", type: FilmType.black_white, iso: 400, desc: "Gritty grain with strong contrast, great for street.", pushable: true),
  ];
}
