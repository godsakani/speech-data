import 'dart:io';
import 'dart:typed_data';

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

  String getSwahiliAudioUrl(String id) => _client.swahiliAudioUrl(id);

  /// Fetches English audio as bytes (for reliable playback on Android).
  Future<Uint8List> getEnglishAudioBytes(String id) =>
      _client.getAudioBytes(_client.englishAudioUrl(id));

  /// Fetches Swahili audio as bytes (for reliable playback on Android).
  Future<Uint8List> getSwahiliAudioBytes(String id) =>
      _client.getAudioBytes(_client.swahiliAudioUrl(id));

  Future<void> submitSwahili(String id, File wavFile) =>
      _client.submitSwahili(id, wavFile);

  /// Replace existing Swahili (resubmit). Use when item is already submitted.
  Future<void> replaceSwahili(String id, File wavFile) =>
      _client.replaceSwahili(id, wavFile);
}
