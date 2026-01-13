import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final DatabaseService _db = DatabaseService();
  
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    try {
      final settings = await _db.getSettings();
      switch (settings.theme) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
      }
    } catch (e) {
      // Default to dark on error
      state = ThemeMode.dark;
    }
  }
  
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final settings = await _db.getSettings();
      String themeStr;
      switch (mode) {
        case ThemeMode.light:
          themeStr = 'light';
          break;
        case ThemeMode.dark:
          themeStr = 'dark';
          break;
        default:
          themeStr = 'system';
      }
      await _db.updateSettings(settings.copyWith(theme: themeStr));
    } catch (e) {
      // Ignore save errors
    }
  }
}
