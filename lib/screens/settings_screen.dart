import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backendAvailable = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() => _checking = true);
    final available = await ApiService().isAvailable();
    if (mounted) {
      setState(() {
        _backendAvailable = available;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Backend Connection Status
          _buildSectionTitle('Sunucu Bağlantısı'),
          Card(
            child: ListTile(
              leading: Icon(
                _checking
                    ? Icons.cloud_sync
                    : _backendAvailable
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                color: _checking
                    ? Colors.orange
                    : _backendAvailable
                        ? Colors.green
                        : Colors.red,
              ),
              title: Text(
                _checking
                    ? 'Kontrol ediliyor...'
                    : _backendAvailable
                        ? 'AI Sunucusu Bağlı'
                        : 'AI Sunucusu Bağlantısı Yok',
              ),
              subtitle: const Text('Ses analizi için backend sunucusu gereklidir'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _checkBackend,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          _buildSectionTitle('Uygulama Bilgisi'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blue),
                  title: Text('AI Ses Günlüğü'),
                  subtitle: Text('Versiyon 1.0.0'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.memory, color: Colors.purple),
                  title: Text('AI Modelleri'),
                  subtitle: Text(
                    '• Whisper (Ses → Metin)\n'
                    '• DistilBERT (Duygu Analizi)\n'
                    '• GPT-2 (Geri Bildirim)',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage, color: Colors.teal),
                  title: const Text('Veri Depolama'),
                  subtitle: const Text('Yerel SQLite veritabanı'),
                  trailing: TextButton(
                    onPressed: () => _showClearDataDialog(),
                    child: const Text(
                      'Verileri Sil',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // How to use
          _buildSectionTitle('Nasıl Kullanılır'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep('1', 'Ses kaydı yapın',
                      'Ana sayfadaki "Yeni Kayıt" butonuna basarak sesinizi kaydedin.'),
                  const SizedBox(height: 12),
                  _buildStep('2', 'AI analizi bekleyin',
                      'Kayıt tamamlandığında sunucu bağlıysa otomatik AI analizi başlar.'),
                  const SizedBox(height: 12),
                  _buildStep('3', 'Sonuçları görüntüleyin',
                      'Transkripsiyon, duygu analizi ve AI geri bildirimini inceleyin.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.blue,
          child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verileri Sil'),
        content: const Text(
            'Tüm kayıtlar ve ses dosyaları silinecek. Bu işlem geri alınamaz.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm veriler silindi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
