import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../api_keys.dart';

/// Cliente mínimo DeepSeek (OpenAI-compatible) para respuestas JSON.
class DeepSeekService {
  final Dio _dio;

  DeepSeekService({Dio? dio}) : _dio = dio ?? Dio();

  static const _baseUrl = 'https://api.deepseek.com/chat/completions';

  Future<Map<String, dynamic>> chatJson({
    required String systemPrompt,
    required String userPrompt,
    String model = 'deepseek-chat',
  }) async {
    if (deepseekApiKey.isEmpty) {
      throw Exception('DeepSeek API key not configured');
    }

    final response = await _dio.post(
      _baseUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer $deepseekApiKey',
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
      data: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.2,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Empty DeepSeek response');
    }

    final clean = content
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    debugPrint('✅ DeepSeek JSON response received (${clean.length} chars)');
    return jsonDecode(clean) as Map<String, dynamic>;
  }
}
