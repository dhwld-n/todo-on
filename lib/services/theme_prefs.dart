import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'themeMode';
const _kTextScaleKey = 'textScale';

Future<ThemeMode?> loadCachedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kThemeModeKey);
  return switch (saved) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => null,
  };
}

Future<void> saveCachedThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kThemeModeKey,
    mode == ThemeMode.dark ? 'dark' : 'light',
  );
}

/// This device's font size setting (1.0 = normal), or null if never set.
Future<double?> loadCachedTextScale() async =>
    (await SharedPreferences.getInstance()).getDouble(_kTextScaleKey);

Future<void> saveCachedTextScale(double scale) async =>
    (await SharedPreferences.getInstance()).setDouble(_kTextScaleKey, scale);
