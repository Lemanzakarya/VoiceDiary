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
  /// Throws an exception if the check itself fails (platform error).
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      print('Error checking permission: $e');
      rethrow;
    }
  }

  // Start recording - assumes permission is already granted
  Future<bool> startRecording() async {
    try {
      // Use Application Support directory – invisible in iOS Files app
      final directory = await getApplicationSupportDirectory();
      // Ensure recordings sub-folder exists
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${recordingsDir.path}/recording_$timestamp.m4a';

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

      // Mark as not recording BEFORE stopping the encoder
      // so no more audio data is buffered.
      _isRecording = false;

      final path = await _audioRecorder.stop();

      // Give the OS a moment to flush the file to disk
      await Future.delayed(const Duration(milliseconds: 300));

      if (path != null && await File(path).exists()) {
        // Verify file is fully written (size > 0)
        final fileSize = await File(path).length();
        if (fileSize > 0) {
          return path;
        }
      }

      // Fallback to the path we set at start
      if (_currentRecordingPath != null &&
          await File(_currentRecordingPath!).exists()) {
        return _currentRecordingPath;
      }

      return null;
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
