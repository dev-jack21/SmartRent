import 'package:flutter/material.dart';

class ThemeService extends ValueNotifier<ThemeMode> {
  ThemeService._() : super(ThemeMode.light);

  static final ThemeService instance = ThemeService._();

  bool get isDarkMode {
    if (value == ThemeMode.dark) return true;
    if (value == ThemeMode.light) return false;
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  void toggleTheme() {
    value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    value = mode;
  }
}
