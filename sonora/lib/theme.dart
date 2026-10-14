import 'package:flutter/material.dart';

const kBg = Color(0xFF121212);
const kCard = Color(0xFF1E1E1E);
const kAccent = Color(0xFF2DE0A5);
const kViolet = Color(0xFF7C3AED);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        secondary: kAccent,
        onSecondaryContainer: kAccent,
        surface: kBg,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF181818),
        indicatorColor: Colors.transparent,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
      ),
    );
