import 'package:flutter/material.dart';
import 'dart:async';
import '../models/diary_entry.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String audioFilePath;

  const ProcessingScreen({super.key, required this.audioFilePath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _statusMessage = 'Ses dosyası yükleniyor...';
  int _currentStep = 0; // 0: upload, 1: transcribe, 2: sentiment, 3: feedback, 4: done
  bool _hasError = false;
  String? _errorMessage;
  int? _backendEntryId;

  final List<_ProcessStep> _steps = [
    _ProcessStep(
      icon: Icons.cloud_upload,
      title: 'Yükleniyor',
      subtitle: 'Ses dosyası sunucuya gönderiliyor...',
    ),
    _ProcessStep(
      icon: Icons.record_voice_over,
      title: 'Ses Tanıma',
      subtitle: 'Whisper AI ile ses metne çevriliyor...',
    ),
    _ProcessStep(
      icon: Icons.emoji_emotions,
      title: 'Duygu Analizi',
      subtitle: 'Metin duygu analizi yapılıyor...',
    ),
    _ProcessStep(
      icon: Icons.psychology,
      title: 'AI Geri Bildirim',
      subtitle: 'Kişiselleştirilmiş geri bildirim oluşturuluyor...',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startProcessing();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startProcessing() async {
    try {
      // Step 1: Upload audio
      setState(() {
        _currentStep = 0;
        _statusMessage = 'Ses dosyası yükleniyor...';
      });

      final uploadResult = await _apiService.uploadAudio(widget.audioFilePath);
      final entryData = uploadResult['entry'] as Map<String, dynamic>;
      _backendEntryId = entryData['id'] as int;

      // Step 2: Wait for AI processing (poll)
      setState(() {
        _currentStep = 1;
        _statusMessage = 'AI analizi başladı, ses tanıma yapılıyor...';
      });

      // Poll for results - the backend processes in background
      final analyzedEntry = await _pollWithStepUpdates(_backendEntryId!);

      if (analyzedEntry != null && mounted) {
        // Navigate to result screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(entry: analyzedEntry),
          ),
        );
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'AI analizi zaman aşımına uğradı. Sonuçlar detay ekranından kontrol edilebilir.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<DiaryEntry?> _pollWithStepUpdates(int entryId) async {
    const pollInterval = Duration(seconds: 3);
    const timeout = Duration(minutes: 5);
    final stopwatch = Stopwatch()..start();

    int pollCount = 0;

    while (stopwatch.elapsed < timeout) {
      try {
        final entry = await _apiService.getEntry(entryId);

        if (entry != null) {
          // Update step based on what's available
          if (entry.transcriptionText != null && _currentStep < 2) {
            setState(() {
              _currentStep = 2;
              _statusMessage = 'Duygu analizi yapılıyor...';
            });
          }
          if (entry.sentimentLabel != null && _currentStep < 3) {
            setState(() {
              _currentStep = 3;
              _statusMessage = 'Geri bildirim oluşturuluyor...';
            });
          }
          if (entry.isAnalyzed) {
            setState(() {
              _currentStep = 4;
              _statusMessage = 'Tamamlandı!';
            });
            await Future.delayed(const Duration(milliseconds: 500));
            return entry;
          }
        }

        // Update status message with estimated time
        pollCount++;
        if (pollCount > 5 && _currentStep == 1) {
          setState(() {
            _statusMessage = 'AI modelleri çalışıyor, lütfen bekleyin...';
          });
        }
      } catch (_) {
        // Continue polling on error
      }

      await Future.delayed(pollInterval);
    }

    // Timeout - return whatever we have
    return await _apiService.getEntry(entryId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Analizi'),
        automaticallyImplyLeading: _hasError,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _hasError ? _buildErrorState() : _buildProcessingState(),
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Column(
      children: [
        const Spacer(flex: 1),

        // Animated icon
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.4),
                    width: 3,
                  ),
                ),
                child: Icon(
                  _steps[_currentStep.clamp(0, _steps.length - 1)].icon,
                  size: 56,
                  color: Colors.blue,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // Status message
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 40),

        // Step indicators
        ...List.generate(_steps.length, (index) {
          return _buildStepIndicator(index);
        }),

        const Spacer(flex: 2),

        // Cancel hint
        Text(
          'Bu işlem birkaç dakika sürebilir',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStepIndicator(int index) {
    final isActive = index == _currentStep;
    final isCompleted = index < _currentStep;
    final isPending = index > _currentStep;

    Color color;
    IconData icon;
    if (isCompleted) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (isActive) {
      color = Colors.blue;
      icon = _steps[index].icon;
    } else {
      color = Colors.grey[400]!;
      icon = _steps[index].icon;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : isActive
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),

          // Title & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _steps[index].title,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isPending ? Colors.grey[400] : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                if (isActive)
                  Text(
                    _steps[index].subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),

          // Status icon
          if (isCompleted)
            const Icon(Icons.check, color: Colors.green, size: 18),
          if (isActive)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 56,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bir hata oluştu',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Bilinmeyen hata',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri Dön'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                    _currentStep = 0;
                  });
                  _startProcessing();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcessStep {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProcessStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
