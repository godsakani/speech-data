import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../domain/entities/paginated_speech.dart';
import '../../domain/entities/speech_item.dart';
import '../../domain/entities/speech_stats.dart';

void _log(String message) {
  debugPrint('[SpeechAPI] $message');
}

class AudioApiClient {
  AudioApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        headers: {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    client.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
    return client;
  }

  final Dio _dio;

  /// Update base URL at runtime (e.g. after user changes it in Settings).
  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
    _log('Base URL updated to: $url');
  }

  Future<PaginatedSpeech> listAudio({int page = 1, int limit = 20}) async {
    _log('GET /api/audio?page=$page&limit=$limit');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/audio',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data!;
      final items = (data['items'] as List)
          .map((e) => SpeechItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = data['total'] as int;
      _log('Response: status=${response.statusCode}, total=$total, items=${items.length}');
      if (kDebugMode && items.isNotEmpty) {
        _log('First item: id=${items.first.id}, length_english=${items.first.lengthEnglish}, status=${items.first.status}');
      }
      return PaginatedSpeech(
        items: items,
        total: total,
        page: data['page'] as int,
        limit: data['limit'] as int,
      );
    } catch (e, stack) {
      _log('Error: $e');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
      rethrow;
    }
  }

  /// Returns the URL to stream English audio (for playback).
  String englishAudioUrl(String id) => '$kBaseUrl/api/audio/$id/english';

  /// Returns the URL to stream submitted Swahili audio (for playback).
  String swahiliAudioUrl(String id) => '$kBaseUrl/api/audio/$id/swahili';

  /// Fetches audio bytes from URL (avoids Android MediaPlayer issues with streaming).
  Future<Uint8List> getAudioBytes(String url) async {
    _log('GET $url (bytes)');
    final response = await _dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  Future<SpeechStats> getStats() async {
    _log('GET /api/audio/stats');
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/audio/stats');
      final stats = SpeechStats.fromJson(response.data!);
      _log('Response: status=${response.statusCode}, total=${stats.total}, submitted=${stats.submitted}, pending=${stats.pending}');
      return stats;
    } catch (e, stack) {
      _log('Error: $e');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
      rethrow;
    }
  }

  Future<void> submitSwahili(String id, File wavFile) async {
    _log('POST /api/audio/$id/swahili');
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/audio/$id/swahili',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            wavFile.path,
            filename: 'swahili.wav',
          ),
        }),
      );
      _log('Response: status=200');
    } catch (e, stack) {
      _log('Error: $e');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
      rethrow;
    }
  }

  /// Replace existing Swahili (resubmit). Use when item is already submitted.
  Future<void> replaceSwahili(String id, File wavFile) async {
    _log('PUT /api/audio/$id/swahili');
    try {
      await _dio.put<Map<String, dynamic>>(
        '/api/audio/$id/swahili',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            wavFile.path,
            filename: 'swahili.wav',
          ),
        }),
      );
      _log('Response: status=200');
    } catch (e, stack) {
      _log('Error: $e');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
      rethrow;
    }
  }
}
