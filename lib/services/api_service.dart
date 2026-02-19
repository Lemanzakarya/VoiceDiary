import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/diary_entry.dart';

class ApiService {
  // iOS simulator uses localhost, Android emulator uses 10.0.2.2
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Check if backend is reachable
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Upload audio file and trigger AI analysis
  /// Returns the created entry data from backend (with backend ID)
  Future<Map<String, dynamic>> uploadAudio(String filePath) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload-audio');
      final request = http.MultipartRequest('POST', uri);

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Ses dosyası bulunamadı: $filePath');
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Yükleme başarısız');
      }
    } catch (e) {
      throw Exception('Ses yükleme hatası: $e');
    }
  }

  /// Get single entry by ID (used for polling AI status)
  Future<DiaryEntry?> getEntry(int entryId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/entries/$entryId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseBackendEntry(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Kayıt alınamadı');
      }
    } catch (e) {
      throw Exception('Kayıt sorgulama hatası: $e');
    }
  }

  /// Get all entries from backend
  Future<List<DiaryEntry>> getEntries({int skip = 0, int limit = 100}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/entries?skip=$skip&limit=$limit'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entriesList = data['entries'] as List;
        return entriesList.map((e) => _parseBackendEntry(e)).toList();
      } else {
        throw Exception('Kayıtlar alınamadı');
      }
    } catch (e) {
      throw Exception('Kayıt listeleme hatası: $e');
    }
  }

  /// Delete entry from backend
  Future<bool> deleteEntry(int entryId) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/entries/$entryId'))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Kayıt silme hatası: $e');
    }
  }

  /// Poll entry until AI analysis is complete
  /// Returns the analyzed entry or null on timeout
  Future<DiaryEntry?> pollForAnalysis(
    int entryId, {
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final entry = await getEntry(entryId);
        if (entry != null && entry.isAnalyzed) {
          return entry;
        }
      } catch (_) {
        // Continue polling on error
      }

      await Future.delayed(pollInterval);
    }

    // Timeout - return whatever we have
    return await getEntry(entryId);
  }

  /// Parse backend snake_case JSON to DiaryEntry
  DiaryEntry _parseBackendEntry(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as int?,
      audioFilePath: json['audio_file_path'] as String? ?? '',
      transcriptionText: json['transcription_text'] as String?,
      sentimentLabel: json['sentiment_label'] as String?,
      sentimentScore: json['sentiment_score'] != null
          ? (json['sentiment_score'] as num).toDouble()
          : null,
      aiFeedback: json['ai_feedback'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
