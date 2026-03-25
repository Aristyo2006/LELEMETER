import 'package:flutter/material.dart';

DecorationImage get skeuomorphicNoise => const DecorationImage(
      image: AssetImage('assets/images/noise.jpg'),
      repeat: ImageRepeat.repeat,
      opacity: 0.08,
      fit: BoxFit.none,
    );
