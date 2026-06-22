import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../film_database.dart';

/// Pure-film-sim color matrices (4×5 = 20 doubles), identical to the ones the
/// viewfinder applies live via `ColorFilter.matrix`. Kept here as plain data so
/// they can be shipped into a background isolate.
///
/// NOTE: this duplicates the viewfinder's look tables *by value*. It must never
/// import the viewfinder (UI) layer. If a look changes, update both places.
List<double>? filmSimMatrix(FilmStock? film) {
  if (film == null) return null;
  final name = film.name.toLowerCase();

  if (film.type == FilmType.blackWhite) {
    if (name.contains('tri-x')) {
      return const [
        0.3, 0.7, 0.1, 0, -20,
        0.3, 0.7, 0.1, 0, -20,
        0.3, 0.7, 0.1, 0, -20,
        0, 0, 0, 1, 0,
      ];
    }
    return const [
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  if (name.contains('portra')) {
    return const [
      1.1, 0.0, 0.0, 0, 5,
      0.0, 1.0, 0.0, 0, 2,
      0.0, 0.0, 0.95, 0, -2,
      0, 0, 0, 1, 0,
    ];
  } else if (name.contains('gold')) {
    return const [
      1.2, 0.0, 0.0, 0, 10,
      0.0, 1.1, 0.0, 0, 5,
      0.0, 0.0, 0.8, 0, -10,
      0, 0, 0, 1, 0,
    ];
  } else if (name.contains('ektar')) {
    return const [
      1.15, 0.05, 0.05, 0, 0,
      0.0, 1.15, 0.0, 0, 0,
      0.0, 0.0, 1.15, 0, 0,
      0, 0, 0, 1, 0,
    ];
  } else if (name.contains('velvia')) {
    return const [
      1.0, 0.0, 0.0, 0, 0,
      0.1, 1.2, 0.0, 0, 5,
      0.0, 0.1, 1.2, 0, 5,
      0, 0, 0, 1, 0,
    ];
  } else if (name.contains('cinestill') || name.contains('vision3')) {
    return const [
      1.0, 0.0, 0.0, 0, 0,
      0.0, 0.9, 0.2, 0, -5,
      0.1, 0.0, 1.2, 0, 10,
      0, 0, 0, 1, 0,
    ];
  }

  if (film.brand == 'Kodak') {
    return const [1.1, 0.05, 0, 0, 5, 0, 1.05, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0];
  } else if (film.brand == 'Fujifilm') {
    return const [0.95, 0, 0, 0, 0, 0, 1.1, 0.05, 0, 0, 0, 0.05, 1.1, 0, 0, 0, 0, 0, 1, 0];
  }

  return null;
}

/// Apply a film-sim matrix to a JPEG *off the UI isolate* and overwrite the file.
/// Returns the (possibly same) path on success, or null to signal "use the
/// original unchanged image".
///
/// The matrix here is the *custom LUT* 4×5 already computed by the viewfinder
/// from a `.cube` file, passed through verbatim. Falls back to [filmSimMatrix].
Future<String?> bakeFilmSim({
  required String sourcePath,
  required FilmStock? film,
  List<double>? customLutMatrix,
  int maxLongEdge = 2048,
}) async {
  final matrix = customLutMatrix ?? filmSimMatrix(film) ?? const [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  final result = await compute(
    _bakeIsolate,
    _BakeInput(sourcePath, matrix, maxLongEdge),
  );
  return result;
}

class _BakeInput {
  final String path;
  final List<double> matrix; // length 20
  final int maxLongEdge;
  const _BakeInput(this.path, this.matrix, this.maxLongEdge);
}

String _bakeIsolate(_BakeInput input) {
  final src = File(input.path);
  final bytes = src.readAsBytesSync();
  var image = img.decodeImage(bytes);
  if (image == null) return input.path; // can't decode → leave as-is
  image = img.bakeOrientation(image);

  // Crop to 3:4 (portrait) or 4:3 (landscape) to match viewfinder
  final isPortrait = image.height > image.width;
  int cropW = image.width;
  int cropH = image.height;
  int cropX = 0;
  int cropY = 0;

  if (isPortrait) {
    // Target aspect ratio 3:4 (0.75)
    final currentAspect = image.width / image.height;
    if (currentAspect > 0.75) {
      cropW = (image.height * 3 / 4).round();
      cropX = (image.width - cropW) ~/ 2;
    } else if (currentAspect < 0.75) {
      cropH = (image.width * 4 / 3).round();
      cropY = (image.height - cropH) ~/ 2;
    }
  } else {
    // Target aspect ratio 4:3 (1.3333)
    final currentAspect = image.width / image.height;
    if (currentAspect > 1.3333) {
      cropW = (image.height * 4 / 3).round();
      cropX = (image.width - cropW) ~/ 2;
    } else if (currentAspect < 1.3333) {
      cropH = (image.width * 3 / 4).round();
      cropY = (image.height - cropH) ~/ 2;
    }
  }

  if (cropW != image.width || cropH != image.height) {
    image = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  }

  // Cap dimensions to keep decode/encode fast and memory bounded.
  final longSide = image.width > image.height ? image.width : image.height;
  if (longSide > input.maxLongEdge) {
    final scale = input.maxLongEdge / longSide;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  final m = input.matrix;
  final r0 = m[0], r1 = m[1], r2 = m[2], r3 = m[3], r4 = m[4];
  final g0 = m[5], g1 = m[6], g2 = m[7], g3 = m[8], g4 = m[9];
  final b0 = m[10], b1 = m[11], b2 = m[12], b3 = m[13], b4 = m[14];

  final out = img.Image(width: image.width, height: image.height);
  for (final px in image) {
    final r = px.r;
    final g = px.g;
    final b = px.b;
    final nr = (r0 * r + r1 * g + r2 * b + r3 * px.a + r4).clamp(0, 255);
    final ng = (g0 * r + g1 * g + g2 * b + g3 * px.a + g4).clamp(0, 255);
    final nb = (b0 * r + b1 * g + b2 * b + b3 * px.a + b4).clamp(0, 255);
    out.setPixelRgba(px.x, px.y, nr.toInt(), ng.toInt(), nb.toInt(), px.a.toInt());
  }

  final encoded = img.encodeJpg(out, quality: 92);
  src.writeAsBytesSync(encoded, flush: true);
  return input.path;
}

/// Reads a JPEG from disk into a decoded [ui.Image] for display, resized to fit
/// [targetWidth]. Useful for smooth full-screen previews without holding the
/// multi-megapixel bitmap in GPU memory.
Future<ui.Image> loadDecodedImage(String path, {int targetWidth = 1080}) async {
  final data = await File(path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(data);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final scale = descriptor.width >= descriptor.height
      ? targetWidth / descriptor.width
      : targetWidth / descriptor.height;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  buffer.dispose();
  return frame.image;
}
