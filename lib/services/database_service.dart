import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/diary_entry.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Bu uygulama web platformunda veritabanı kullanamaz. '
        'Lütfen mobil cihazda veya masaüstünde çalıştırın.'
      );
    }
    
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'voice_diary.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diary_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audioFilePath TEXT NOT NULL,
        transcriptionText TEXT,
        sentimentLabel TEXT,
        sentimentScore REAL,
        aiFeedback TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // Insert a new diary entry
  Future<int> insertEntry(DiaryEntry entry) async {
    final db = await database;
    return await db.insert(
      'diary_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all diary entries (ordered by most recent first)
  Future<List<DiaryEntry>> getAllEntries() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'diary_entries',
        orderBy: 'createdAt DESC',
      );

      return List.generate(maps.length, (i) {
        return DiaryEntry.fromMap(maps[i]);
      });
    } catch (e) {
      print('Database error: $e');
      return [];
    }
  }

  // Get a single entry by ID
  Future<DiaryEntry?> getEntry(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'diary_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return DiaryEntry.fromMap(maps.first);
  }

  // Update an existing entry
  Future<int> updateEntry(DiaryEntry entry) async {
    final db = await database;
    return await db.update(
      'diary_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // Delete an entry
  Future<int> deleteEntry(int id) async {
    final db = await database;
    return await db.delete(
      'diary_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get entries filtered by date range
  Future<List<DiaryEntry>> getEntriesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'diary_entries',
      where: 'createdAt BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return DiaryEntry.fromMap(maps[i]);
    });
  }

  // Get entries by sentiment
  Future<List<DiaryEntry>> getEntriesBySentiment(String sentiment) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'diary_entries',
      where: 'sentimentLabel = ?',
      whereArgs: [sentiment],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return DiaryEntry.fromMap(maps[i]);
    });
  }

  // Search entries by transcription text
  Future<List<DiaryEntry>> searchEntries(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'diary_entries',
      where: 'transcriptionText LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return DiaryEntry.fromMap(maps[i]);
    });
  }

  // Get count of entries
  Future<int> getEntriesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM diary_entries');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Delete all entries (use with caution)
  Future<int> deleteAllEntries() async {
    final db = await database;
    return await db.delete('diary_entries');
  }

  // Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
