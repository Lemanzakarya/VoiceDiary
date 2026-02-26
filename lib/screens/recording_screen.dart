import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/recording_service.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../models/diary_entry.dart';
import 'processing_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with WidgetsBindingObserver {
  final RecordingService _recordingService = RecordingService();
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();
  
  bool _isRecording = false;
  bool _isPaused = false;
  bool _waitingForPermission = false;
  int _recordingDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from Settings, re-check permission automatically
    if (state == AppLifecycleState.resumed && _waitingForPermission) {
      _waitingForPermission = false;
      _startRecording();
    }
  }

  void _startTimer() {
    _recordingDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    bool hasPermission;
    try {
      hasPermission = await _recordingService.hasPermission();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mikrofon izni kontrol edilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (!hasPermission) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mikrofon İzni Gerekli'),
            content: const Text(
              'Ses kaydı yapabilmek için mikrofon iznine ihtiyaç var. '
              'Lütfen ayarlardan mikrofon iznini açın.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openSettings();
                },
                child: const Text('Ayarlara Git'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final success = await _recordingService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
      _startTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başlatılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    _waitingForPermission = true;
    // Open platform-specific app settings
    final Uri settingsUri;
    if (Platform.isIOS) {
      settingsUri = Uri.parse('app-settings:');
    } else if (Platform.isAndroid) {
      settingsUri = Uri.parse('package:com.example.voice_diary');
    } else {
      // macOS / others - open System Preferences
      settingsUri = Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone');
    }
    try {
      await launchUrl(settingsUri);
    } catch (_) {
      // Fallback: just set the flag, user needs to open settings manually
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen cihaz ayarlarından mikrofon iznini manuel olarak açın.'),
          ),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    final success = await _recordingService.pauseRecording();
    if (success) {
      setState(() {
        _isPaused = true;
      });
      _stopTimer();
    }
  }

  Future<void> _resumeRecording() async {
    final success = await _recordingService.resumeRecording();
    if (success) {
      setState(() {
        _isPaused = false;
      });
      _startTimer();
    }
  }

  Future<void> _stopRecording() async {
    final audioPath = await _recordingService.stopRecording();
    _stopTimer();
    
    if (audioPath != null) {
      // Save to local database first
      final entry = DiaryEntry(
        audioFilePath: audioPath,
        createdAt: DateTime.now(),
      );
      
      final localId = await _databaseService.insertEntry(entry);
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingDuration = 0;
      });

      if (!mounted) return;

      // Check if backend is available for AI analysis
      final backendAvailable = await _apiService.isAvailable();

      if (backendAvailable && mounted) {
        // Navigate to processing screen for AI analysis
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingScreen(
              audioFilePath: audioPath,
              localEntryId: localId,
            ),
          ),
        );
      } else if (mounted) {
        // Backend not available - just save locally
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt kaydedildi (AI analizi için sunucu bağlantısı gerekli)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _recordingService.cancelRecording();
    _stopTimer();
    
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingDuration = 0;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ses Kaydı'),
        automaticallyImplyLeading: !_isRecording,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Microphone Icon with animation
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.2),
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.blue,
                  width: 4,
                ),
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 100,
                color: _isRecording ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(height: 40),

            // Duration display
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Status text
            Text(
              _isRecording
                  ? (_isPaused ? 'Durakladı' : 'Kayıt ediliyor...')
                  : 'Kayda başlamak için butona basın',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 60),

            // Control buttons
            if (!_isRecording) ...[
              // Start Recording Button
              ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic, size: 32),
                label: const Text(
                  'Kayıt Başlat',
                  style: TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ] else ...[
              // Recording controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pause/Resume Button
                  IconButton(
                    onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      size: 40,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(width: 30),

                  // Stop Button
                  IconButton(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop, size: 40),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(width: 30),

                  // Cancel Button
                  IconButton(
                    onPressed: _cancelRecording,
                    icon: const Icon(Icons.close, size: 40),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(20),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
