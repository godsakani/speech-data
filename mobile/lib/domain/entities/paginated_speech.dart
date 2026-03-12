import '../entities/speech_item.dart';

class PaginatedSpeech {
  final List<SpeechItem> items;
  final int total;
  final int page;
  final int limit;

  const PaginatedSpeech({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  bool get hasMore => (page * limit) < total;
}
