import 'dart:io';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

/// Renders a camera-captured photo with a skeuomorphic instant-film developing animation.
/// Transitions from a blurry, warm cream emulsion film into a fully saturated and focused image.
class DevelopingPhoto extends StatefulWidget {
  final String imagePath;
  final BoxFit fit;

  const DevelopingPhoto({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.contain,
  });

  @override
  State<DevelopingPhoto> createState() => _DevelopingPhotoState();
}

class _DevelopingPhotoState extends State<DevelopingPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      ),
    );

    _blurAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _opacityAnimation.value;
        final blur = _blurAnimation.value;

        Widget mainImage = Image.file(
          File(widget.imagePath),
          fit: widget.fit,
          gaplessPlayback: true,
          cacheWidth: 1200,
          errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
        );

        if (_controller.value < 0.9) {
          final sat = lerpDouble(0.3, 1.0, _controller.value)!;
          mainImage = ColorFiltered(
            colorFilter: ColorFilter.matrix([
              0.213 + 0.787 * sat,
              0.715 - 0.715 * sat,
              0.072 - 0.072 * sat,
              0.0,
              0.0,
              0.213 - 0.213 * sat,
              0.715 + 0.285 * sat,
              0.072 - 0.072 * sat,
              0.0,
              0.0,
              0.213 - 0.213 * sat,
              0.715 - 0.715 * sat,
              0.072 + 0.928 * sat,
              0.0,
              0.0,
              0.0,
              0.0,
              0.0,
              1.0,
              0.0,
            ]),
            child: mainImage,
          );
        }

        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: mainImage),
              if (opacity > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(color: const Color(0xFFFDFBF7)),
                  ),
                ),
              if (blur > 0.0)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: Container(color: Colors.transparent),
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
