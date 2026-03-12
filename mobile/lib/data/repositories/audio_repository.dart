import 'dart:io';

import '../../domain/entities/paginated_speech.dart';
import '../../domain/entities/speech_stats.dart';
import '../datasources/audio_api_client.dart';

class AudioRepository {
  AudioRepository({AudioApiClient? client})
      : _client = client ?? AudioApiClient();

  final AudioApiClient _client;

  Future<PaginatedSpeech> getList({int page = 1, int limit = 20}) =>
      _client.listAudio(page: page, limit: limit);

  Future<SpeechStats> getStats() => _client.getStats();

  String getEnglishAudioUrl(String id) => _client.englishAudioUrl(id);

  Future<void> submitSwahili(String id, File wavFile) =>
      _client.submitSwahili(id, wavFile);
}
