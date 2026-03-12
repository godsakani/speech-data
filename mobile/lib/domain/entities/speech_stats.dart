class SpeechStats {
  final int total;
  final int submitted;
  final int pending;

  const SpeechStats({
    required this.total,
    required this.submitted,
    required this.pending,
  });

  factory SpeechStats.fromJson(Map<String, dynamic> json) {
    return SpeechStats(
      total: json['total'] as int,
      submitted: json['submitted'] as int,
      pending: json['pending'] as int,
    );
  }

  double get progressFraction => total > 0 ? submitted / total : 0.0;
  int get progressPercent => (progressFraction * 100).round();
}
