import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  // Player state streams
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Duration? get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;

  /// Load an audio file from the given path
  Future<Duration?> loadFile(String filePath) async {
    try {
      final duration = await _player.setFilePath(filePath);
      return duration;
    } catch (e) {
      print('Error loading audio file: $e');
      return null;
    }
  }

  /// Play the loaded audio
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  /// Pause the audio
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  /// Stop the audio and reset position
  Future<void> stop() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  /// Dispose the player
  void dispose() {
    _player.dispose();
  }
}
