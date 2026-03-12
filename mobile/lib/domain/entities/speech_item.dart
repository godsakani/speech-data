class SpeechItem {
  final String id;
  final double lengthEnglish;
  final double? lengthSwahili;
  final String status; // 'pending' | 'submitted'

  const SpeechItem({
    required this.id,
    required this.lengthEnglish,
    this.lengthSwahili,
    required this.status,
  });

  factory SpeechItem.fromJson(Map<String, dynamic> json) {
    return SpeechItem(
      id: json['id'] as String,
      lengthEnglish: (json['length_english'] as num).toDouble(),
      lengthSwahili: json['length_swahili'] != null
          ? (json['length_swahili'] as num).toDouble()
          : null,
      status: json['status'] as String? ?? 'pending',
    );
  }

  bool get isSubmitted => status == 'submitted';
}
