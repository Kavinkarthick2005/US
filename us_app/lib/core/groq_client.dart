import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class GroqClient {
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model   = 'llama-3.1-8b-instant';

  // ── Chat — used by AI companion ───────────────────────────────────────────

  static Future<String> chat(
    String userMessage,
    String partnerContext,
    List<Map<String, String>> history,
  ) async {
    final systemMessage = """
You are a warm, emotionally intelligent relationship companion assistant.
You know these things about the user's partner:
$partnerContext

Help the user care for their partner better.
Give practical, specific, thoughtful suggestions. Under 120 words.
Be warm but not cheesy. Use the partner context when answering.
Never be manipulative. Never suggest surveillance.
Help with: date ideas, gifts, cooking, care, communication.
""";

    final conversationHistory = history.length > 6
        ? history.sublist(history.length - 6)
        : history;

    return _call(
      messages: [
        {'role': 'system', 'content': systemMessage.trim()},
        ...conversationHistory,
        {'role': 'user', 'content': userMessage},
      ],
      maxTokens: 400,
    );
  }

  // ── Prompt — used by gift search, food AI, and other one-shot features ────

  static Future<String> prompt(
    String systemPrompt,
    String userPrompt, {
    int maxTokens = 600,
  }) async {
    return _call(
      messages: [
        {'role': 'system', 'content': systemPrompt.trim()},
        {'role': 'user',   'content': userPrompt},
      ],
      maxTokens: maxTokens,
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<String> _call({
    required List<Map<String, String>> messages,
    int maxTokens = 400,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer ${Env.groqApiKey}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Connection': 'keep-alive',
          'User-Agent': 'UsApp/2.0',
        },
        body: jsonEncode({
          'model':       _model,
          'messages':    messages,
          'max_tokens':  maxTokens,
          'temperature': 0.75,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.trim() ??
            "I couldn't think right now. Try again in a moment 💕";
      } else {
        return "I couldn't think right now. Try again in a moment 💕";
      }
    } catch (e) {
      return "I couldn't think right now. Try again in a moment 💕";
    }
  }
}
