import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/groq_client.dart';
import 'memory_provider.dart';

class ChatMessage {
  final String role; // 'user' or 'ai'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  ChatState({
    required this.messages,
    required this.isLoading,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;

  ChatNotifier(this.ref) : super(ChatState(messages: [], isLoading: false)) {
    loadHistory();
  }

  static const _prefKey = 'ai_chat_history_v1';

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        final List decoded = jsonDecode(saved);
        final list = decoded.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
        state = ChatState(messages: list, isLoading: false);
      }

      // Check SharedPreferences for pre-filled message from timetable (P12 free time banner)
      final prefill = prefs.getString('ai_chat_prefill');
      if (prefill != null && prefill.isNotEmpty) {
        await prefs.remove('ai_chat_prefill');
        // Auto-send after a small delay to allow UI to mount and listen
        Future.delayed(const Duration(milliseconds: 300), () {
          sendMessage(prefill);
        });
      }
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    state = ChatState(messages: [], isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // 1. Add user ChatMessage to state
    final userMsg = ChatMessage(
      role: 'user',
      content: message.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      // 2. Fetch partner memories from memoryProvider
      final memoryNotifier = ref.read(memoryProvider.notifier);
      var memories = memoryNotifier.partnerMemories;

      // Robust single-user fallback: if partnerMemories is empty,
      // load all user memories to ensure a seamless companion experience before linking.
      if (memories.isEmpty) {
        memories = ref.read(memoryProvider).valueOrNull ?? [];
      }

      // 3. Build partner context string
      final partnerContext = memories.isEmpty
          ? "No specific memories or preferences recorded yet."
          : memories.map((m) => "- [${m.category}]: ${m.content}").join("\n");

      // 4. Map last 6 messages as history list of [{role, content}]
      final lastMessages = state.messages.length > 7
          ? state.messages.sublist(state.messages.length - 7, state.messages.length - 1)
          : state.messages.sublist(0, state.messages.length - 1);

      final List<Map<String, String>> history = lastMessages.map((m) {
        return {
          'role': m.role == 'user' ? 'user' : 'assistant',
          'content': m.content,
        };
      }).toList();

      // 5. Query Groq completion
      final responseText = await GroqClient.chat(
        message.trim(),
        partnerContext,
        history,
      );

      // 6. Add AI response ChatMessage
      final aiMsg = ChatMessage(
        role: 'ai',
        content: responseText,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );

      // 7. Persist last 20 messages to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final messagesToSave = state.messages.length > 20
          ? state.messages.sublist(state.messages.length - 20)
          : state.messages;

      final encoded = jsonEncode(messagesToSave.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, encoded);
    } catch (_) {
      final errorMsg = ChatMessage(
        role: 'ai',
        content: "I couldn't think right now. Try again in a moment 💕",
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
