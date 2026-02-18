class DiaryEntry {
  final int? id;
  final String audioFilePath;
  final String? transcriptionText;
  final String? sentimentLabel;
  final double? sentimentScore;
  final String? aiFeedback;
  final DateTime createdAt;

  DiaryEntry({
    this.id,
    required this.audioFilePath,
    this.transcriptionText,
    this.sentimentLabel,
    this.sentimentScore,
    this.aiFeedback,
    required this.createdAt,
  });

  // Convert DiaryEntry to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audioFilePath': audioFilePath,
      'transcriptionText': transcriptionText,
      'sentimentLabel': sentimentLabel,
      'sentimentScore': sentimentScore,
      'aiFeedback': aiFeedback,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create DiaryEntry from Map
  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      audioFilePath: map['audioFilePath'] as String,
      transcriptionText: map['transcriptionText'] as String?,
      sentimentLabel: map['sentimentLabel'] as String?,
      sentimentScore: map['sentimentScore'] as double?,
      aiFeedback: map['aiFeedback'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // Copy with method for updating entries
  DiaryEntry copyWith({
    int? id,
    String? audioFilePath,
    String? transcriptionText,
    String? sentimentLabel,
    double? sentimentScore,
    String? aiFeedback,
    DateTime? createdAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      transcriptionText: transcriptionText ?? this.transcriptionText,
      sentimentLabel: sentimentLabel ?? this.sentimentLabel,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      aiFeedback: aiFeedback ?? this.aiFeedback,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper method to check if entry has been analyzed
  bool get isAnalyzed =>
      transcriptionText != null &&
      sentimentLabel != null &&
      aiFeedback != null;

  // Get sentiment emoji based on label
  String get sentimentEmoji {
    switch (sentimentLabel?.toLowerCase()) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😔';
      case 'neutral':
        return '😐';
      default:
        return '❓';
    }
  }
}
