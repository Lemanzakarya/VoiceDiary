import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';
import '../models/diary_entry.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';

class EntryDetailScreen extends StatefulWidget {
  final DiaryEntry entry;

  const EntryDetailScreen({super.key, required this.entry});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final AudioPlayerService _playerService = AudioPlayerService();
  late DiaryEntry _entry;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _audioExists = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration?>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Check if audio file exists
    final file = File(_entry.audioFilePath);
    final exists = await file.exists();

    setState(() {
      _audioExists = exists;
    });

    if (!exists) return;

    // Load file
    final duration = await _playerService.loadFile(_entry.audioFilePath);
    if (duration != null && mounted) {
      setState(() {
        _duration = duration;
      });
    }

    // Listen to player state changes
    _playerStateSub = _playerService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });

        // Reset when playback completes
        if (state.processingState == ProcessingState.completed) {
          _playerService.seek(Duration.zero);
          _playerService.pause();
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      }
    });

    // Listen to position changes
    _positionSub = _playerService.positionStream.listen((pos) {
      if (pos != null && mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    // Listen to duration changes
    _durationSub = _playerService.durationStream.listen((dur) {
      if (dur != null && mounted) {
        setState(() {
          _duration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerService.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(date);
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: const Text('Bu kaydı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().deleteEntry(_entry.id!);
      // Delete audio file
      final file = File(_entry.audioFilePath);
      if (await file.exists()) {
        await file.delete();
      }
      if (mounted) {
        Navigator.pop(context, true); // true = entry deleted
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteEntry,
            tooltip: 'Sil',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date
            _buildDateCard(),
            const SizedBox(height: 16),

            // Audio Player
            _buildAudioPlayer(),
            const SizedBox(height: 16),

            // Transcription
            _buildTranscriptionCard(),
            const SizedBox(height: 16),

            // Sentiment Analysis
            _buildSentimentCard(),
            const SizedBox(height: 16),

            // AI Feedback
            _buildFeedbackCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.blue),
        title: Text(
          _formatDate(_entry.createdAt),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.headphones, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Ses Kaydı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_audioExists)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ses dosyası bulunamadı',
                  style: TextStyle(color: Colors.red),
                ),
              )
            else ...[
              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blue,
                  inactiveTrackColor: Colors.blue.withValues(alpha: 0.2),
                  thumbColor: Colors.blue,
                  overlayColor: Colors.blue.withValues(alpha: 0.1),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                  value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
                  onChanged: (value) {
                    _playerService.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),

              // Time indicators
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Play/Pause button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    iconSize: 32,
                    onPressed: () {
                      final newPos = _position - const Duration(seconds: 10);
                      _playerService.seek(
                        newPos < Duration.zero ? Duration.zero : newPos,
                      );
                    },
                  ),
                  const SizedBox(width: 16),

                  // Play/Pause
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      iconSize: 40,
                      onPressed: () {
                        if (_isPlaying) {
                          _playerService.pause();
                        } else {
                          _playerService.play();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Forward 10s
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    iconSize: 32,
                    onPressed: () {
                      final newPos = _position + const Duration(seconds: 10);
                      _playerService.seek(
                        newPos > _duration ? _duration : newPos,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.text_snippet, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Transkripsiyon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_entry.transcriptionText != null)
              Text(
                _entry.transcriptionText!,
                style: const TextStyle(fontSize: 16, height: 1.6),
              )
            else
              _buildPendingBanner(
                'Henüz analiz edilmedi',
                'AI modeli entegre edildiğinde ses kaydınız otomatik olarak metne çevrilecek.',
                Icons.pending_actions,
                Colors.teal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_emotions, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Duygu Analizi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_entry.sentimentLabel != null) ...[
              Center(
                child: Column(
                  children: [
                    Text(
                      _entry.sentimentEmoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getSentimentColor(_entry.sentimentLabel)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _entry.sentimentLabel!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getSentimentColor(_entry.sentimentLabel),
                        ),
                      ),
                    ),
                    if (_entry.sentimentScore != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _entry.sentimentScore!,
                        backgroundColor: Colors.grey[200],
                        color: _getSentimentColor(_entry.sentimentLabel),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Skor: ${(_entry.sentimentScore! * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ] else
              _buildPendingBanner(
                'Henüz analiz edilmedi',
                'AI modeli entegre edildiğinde konuşmanızdaki duygusal ton analiz edilecek.',
                Icons.pending_actions,
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'AI Geri Bildirim',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_entry.aiFeedback != null)
              Text(
                _entry.aiFeedback!,
                style: const TextStyle(fontSize: 16, height: 1.6),
              )
            else
              _buildPendingBanner(
                'Henüz geri bildirim yok',
                'AI modeli entegre edildiğinde size kişiselleştirilmiş geri bildirim ve öneriler sunulacak.',
                Icons.pending_actions,
                Colors.purple,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBanner(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSentimentColor(String? sentiment) {
    switch (sentiment?.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'neutral':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
