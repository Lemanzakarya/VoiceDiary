import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class DiaryProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();

  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  bool _backendAvailable = false;

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get backendAvailable => _backendAvailable;

  /// Check if backend is reachable
  Future<void> checkBackend() async {
    _backendAvailable = await _apiService.isAvailable();
    notifyListeners();
  }

  /// Load all diary entries from the database
  Future<void> loadEntries() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _entries = await _databaseService.getAllEntries();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Kayıtlar yüklenirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Add a new entry
  Future<void> addEntry(DiaryEntry entry) async {
    try {
      await _databaseService.insertEntry(entry);
      await loadEntries();
    } catch (e) {
      _error = 'Kayıt eklenirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Update an existing entry
  Future<void> updateEntry(DiaryEntry entry) async {
    try {
      await _databaseService.updateEntry(entry);
      await loadEntries();
    } catch (e) {
      _error = 'Kayıt güncellenirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Delete an entry
  Future<void> deleteEntry(int id) async {
    try {
      await _databaseService.deleteEntry(id);
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Kayıt silinirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Search entries
  Future<void> searchEntries(String query) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (query.isEmpty) {
        _entries = await _databaseService.getAllEntries();
      } else {
        _entries = await _databaseService.searchEntries(query);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Arama sırasında hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Get entries count
  Future<int> getEntriesCount() async {
    return await _databaseService.getEntriesCount();
  }
}
