import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'voice_diary.db');
      final db = await openDatabase(path);

      // Create settings table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      final result = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['dark_mode'],
      );

      if (result.isNotEmpty) {
        _themeMode = result.first['value'] == 'true'
            ? ThemeMode.dark
            : ThemeMode.light;
        notifyListeners();
      }
    } catch (_) {
      // Fallback to light theme
    }
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'voice_diary.db');
      final db = await openDatabase(path);

      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      await db.insert(
        'app_settings',
        {'key': 'dark_mode', 'value': isDarkMode.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Non-critical – theme still changes in memory
    }
  }
}
