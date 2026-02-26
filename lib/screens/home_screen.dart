import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../services/audio_player_service.dart';
import 'recording_screen.dart';
import 'entry_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AudioPlayerService? _quickPlayer;
  int? _playingEntryId;
  bool _isSearching = false;
  String? _activeFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DiaryProvider>();
      provider.loadEntries();
      provider.checkBackend();
    });
  }

  @override
  void dispose() {
    _quickPlayer?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(DiaryEntry entry) async {
    if (_playingEntryId == entry.id && _quickPlayer != null && _quickPlayer!.isPlaying) {
      await _quickPlayer!.stop();
      setState(() {
        _playingEntryId = null;
      });
      return;
    }

    _quickPlayer?.dispose();
    _quickPlayer = AudioPlayerService();

    final duration = await _quickPlayer!.loadFile(entry.audioFilePath);
    if (duration == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ses dosyası açılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _playingEntryId = entry.id;
    });

    await _quickPlayer!.play();

    _quickPlayer!.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed || !state.playing) {
        if (mounted) {
          setState(() {
            _playingEntryId = null;
          });
        }
      }
    });
  }

  Future<void> _navigateToRecording() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const RecordingScreen()),
    );

    if (result == true && mounted) {
      context.read<DiaryProvider>().loadEntries();
    }
  }

  Future<void> _navigateToDetail(DiaryEntry entry) async {
    _quickPlayer?.stop();
    setState(() {
      _playingEntryId = null;
    });

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EntryDetailScreen(entry: entry),
      ),
    );

    if (result == true && mounted) {
      context.read<DiaryProvider>().loadEntries();
    }
  }

  Future<void> _deleteEntry(int id) async {
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

    if (confirmed == true && mounted) {
      context.read<DiaryProvider>().deleteEntry(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt silindi'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(date);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Kayıtlarda ara...',
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  context.read<DiaryProvider>().searchEntries(query);
                },
              )
            : const Text('Ses Günlüğüm'),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  context.read<DiaryProvider>().loadEntries();
                }
              });
            },
          ),
          // Backend status indicator
          Consumer<DiaryProvider>(
            builder: (context, provider, _) {
              return Tooltip(
                message: provider.backendAvailable
                    ? 'AI Sunucusu: Bağlı'
                    : 'AI Sunucusu: Bağlantı yok',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.cloud,
                    color: provider.backendAvailable
                        ? Colors.green
                        : Colors.grey[400],
                    size: 20,
                  ),
                ),
              );
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sentiment filter chips
          _buildFilterChips(),
          // Entry list
          Expanded(
            child: Consumer<DiaryProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.entries.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildEntriesList(provider.entries);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToRecording,
        icon: const Icon(Icons.mic),
        label: const Text('Yeni Kayıt'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      (label: 'Tümü', value: null as String?, icon: '📋'),
      (label: 'Olumlu', value: 'POSITIVE' as String?, icon: '😊'),
      (label: 'Olumsuz', value: 'NEGATIVE' as String?, icon: '😔'),
      (label: 'Nötr', value: 'neutral' as String?, icon: '😐'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _activeFilter == f.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text('${f.icon} ${f.label}'),
              onSelected: (_) {
                setState(() {
                  _activeFilter = f.value;
                });
                context.read<DiaryProvider>().filterBySentiment(_activeFilter);
              },
              selectedColor: Colors.blue.withValues(alpha: 0.2),
              checkmarkColor: Colors.blue,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Henüz kayıt yok',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'İlk ses günlüğünüzü kaydetmek için\naşağıdaki butona basın',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(List<DiaryEntry> entries) {
    return RefreshIndicator(
      onRefresh: () => context.read<DiaryProvider>().loadEntries(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          return _buildEntryCard(entries[index]);
        },
      ),
    );
  }

  Widget _buildEntryCard(DiaryEntry entry) {
    final isCurrentlyPlaying = _playingEntryId == entry.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(entry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(entry.createdAt),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (entry.sentimentLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSentimentColor(entry.sentimentLabel).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.sentimentEmoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            entry.sentimentLabel!,
                            style: TextStyle(
                              color: _getSentimentColor(entry.sentimentLabel),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Transcription preview
              if (entry.transcriptionText != null)
                Text(
                  entry.transcriptionText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                )
              else
                const Text(
                  'Analiz bekleniyor...',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      isCurrentlyPlaying ? Icons.stop_circle : Icons.play_circle,
                      color: isCurrentlyPlaying ? Colors.red : Colors.blue,
                    ),
                    iconSize: 32,
                    onPressed: () => _togglePlay(entry),
                    tooltip: isCurrentlyPlaying ? 'Durdur' : 'Dinle',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: () => _navigateToDetail(entry),
                    tooltip: 'Detay',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteEntry(entry.id!),
                    tooltip: 'Sil',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
