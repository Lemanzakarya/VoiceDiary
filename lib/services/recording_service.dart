import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Checks and requests microphone permission.
  /// On first call, shows system dialog.
  /// Returns true if granted, false otherwise.
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  // Start recording - assumes permission is already granted
  Future<bool> startRecording() async {
    try {
      // Generate file path
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/recording_$timestamp.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        return null;
      }

      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null && await File(path).exists()) {
        return path;
      }

      return _currentRecordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // Pause recording
  Future<bool> pauseRecording() async {
    try {
      if (!_isRecording) {
        return false;
      }

      await _audioRecorder.pause();
      return true;
    } catch (e) {
      print('Error pausing recording: $e');
      return false;
    }
  }

  // Resume recording
  Future<bool> resumeRecording() async {
    try {
      await _audioRecorder.resume();
      return true;
    } catch (e) {
      print('Error resuming recording: $e');
      return false;
    }
  }

  // Cancel recording (stop and delete file)
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.stop();
      _isRecording = false;

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  // Get recording duration (in seconds)
  Future<Duration?> getRecordingDuration() async {
    try {
      if (_currentRecordingPath == null) {
        return null;
      }

      // This would need additional implementation
      // For now, return null
      return null;
    } catch (e) {
      print('Error getting duration: $e');
      return null;
    }
  }

  // Delete a recording file
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting recording: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _audioRecorder.dispose();
  }
}
