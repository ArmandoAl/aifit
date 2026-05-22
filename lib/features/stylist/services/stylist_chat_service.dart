import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../api_keys.dart';
import '../../wardrobe/domain/wardrobe_palette.dart';
import '../domain/stylist_chat_response.dart';
import '../domain/stylist_intent_state.dart';

/// GPT-4.1-mini — solo conversación e intent acumulado (sin lógica de app).
class StylistChatService {
  final Dio _dio;

  StylistChatService({Dio? dio}) : _dio = dio ?? Dio();

  static const _model = 'gpt-4.1-mini';

  static String get _systemPrompt => '''
You are OutfitAI — a premium personal fashion stylist.

YOUR ROLE:
- Have a warm, concise, modern conversation.
- Ask ONE focused follow-up question when key details are missing.
- Never generate outfits or item lists yourself.
- Never mention APIs, JSON, or backend systems.

YOU MUST RETURN ONLY valid JSON with this exact shape:
{
  "assistantMessage": "string — what the user sees",
  "intentState": {
    "occasion": "string | null",
    "colors": ["string"],
    "styleTags": ["string"],
    "season": "spring|summer|fall|winter|null",
    "weather": "sunny|rainy|cold|warm|null",
    "formality": 0.0-1.0,
    "layeringPreference": "light|medium|heavy|null",
    "vibe": ["string"],
    "semanticTargets": {
      "formality": 0.0-1.0,
      "occasionSlugs": ["everyday","casual_outing","office","formal_event","beach_dinner","summer_date","vacation","active_wear","work_casual"],
      "climateKeys": ["hot_weather","humid_weather","cold_weather"],
      "aestheticSlugs": ["casual","formal","streetwear","luxury","minimalist","old_money","quiet_luxury","sporty","vintage"],
      "preferLowContrast": true|false|null,
      "preferMutedColors": true|false|null
    }
  },
  "readyToGenerate": true|false,
  "missingFields": ["occasion","colors","styleTags"]
}

RULES:
- Merge new info with CURRENT_INTENT — never drop known fields unless user changes them.
- readyToGenerate=true only when occasion is clear AND (colors OR styleTags OR vibe) exist.
- Keep assistantMessage under 3 short sentences.
- Be premium, confident, helpful — not salesy.

LANGUAGE (critical):
- assistantMessage: ALWAYS Spanish (neutral LATAM). Never English in what the user reads.
- User may write in Spanish or English; understand both.
- intentState.colors: ONLY English slugs from this list: ${WardrobePalette.colorsForPrompt}
- intentState.styleTags: ONLY English slugs from: ${WardrobePalette.styleTagsForPrompt}
- intentState.season: only spring|summer|fall|winter|null (never Spanish season names in JSON).
- intentState.occasion: use English slugs casual|formal|sport|party|work|date|everyday when possible.
- Map Spanish user words to English slugs in JSON (e.g. negro→black, deportivo→sporty, primavera→spring).
''';

  Future<StylistChatResponse> chat({
    required String userMessage,
    required StylistIntentState currentIntent,
    required List<MapEntry<String, String>> recentTurns,
  }) async {
    if (openAiApiKey.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    final historyText = recentTurns
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    final userPayload = '''
CURRENT_INTENT:
${jsonEncode(currentIntent.toJson())}

RECENT_CHAT:
${historyText.isEmpty ? '(new session)' : historyText}

USER_MESSAGE:
$userMessage
''';

    final response = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $openAiApiKey',
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 30),
      ),
      data: {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userPayload},
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.6,
      },
    );

    final content =
        response.data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Empty OpenAI response');
    }

    final clean = content.replaceAll('```json', '').replaceAll('```', '').trim();
    final json = jsonDecode(clean) as Map<String, dynamic>;
    debugPrint('✅ Stylist chat response: ready=${json['readyToGenerate']}');
    return StylistChatResponse.fromJson(json);
  }
}
