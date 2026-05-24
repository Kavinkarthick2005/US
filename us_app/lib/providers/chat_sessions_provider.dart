import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/groq_client.dart';
import 'memory_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ChatSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  ChatSession copyWith({String? title}) => ChatSession(
        id: id,
        userId: userId,
        title: title ?? this.title,
        createdAt: createdAt,
      );
}

class ChatMessage {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'ai'
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

// ── State ─────────────────────────────────────────────────────────────────────

class ChatSessionsState {
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSendingMessage;

  const ChatSessionsState({
    this.sessions = const [],
    this.activeSessionId,
    this.messages = const [],
    this.isLoading = false,
    this.isSendingMessage = false,
  });

  List<ChatMessage> get activeMessages {
    final active = activeSessionId;
    if (active == null) return [];
    return messages
        .where((m) => m.sessionId == active)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  ChatSessionsState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    bool clearActiveSession = false,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSendingMessage,
  }) {
    return ChatSessionsState(
      sessions: sessions ?? this.sessions,
      activeSessionId:
          clearActiveSession ? null : (activeSessionId ?? this.activeSessionId),
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ChatSessionsNotifier extends StateNotifier<ChatSessionsState> {
  final Ref _ref;
  final _sb = Supabase.instance.client;

  ChatSessionsNotifier(this._ref) : super(const ChatSessionsState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    await _loadSessions();
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadSessions() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _sb
          .from('chat_sessions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final sessions = (data as List)
          .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
          .toList();

      state = state.copyWith(sessions: sessions);

      if (sessions.isNotEmpty) {
        await selectSession(sessions.first.id);
      }
    } catch (_) {
      // Table may not exist yet — graceful fallback
      state = state.copyWith(sessions: []);
    }
  }

  Future<void> cleanupEmptySession(String? sessionId) async {
    if (sessionId == null) return;
    // We only clean up if there are NO messages for this session
    // AND it exists in our local sessions list
    final hasMessages = state.messages.any((m) => m.sessionId == sessionId);
    if (!hasMessages) {
      // It's empty. Delete it silently.
      await deleteSession(sessionId);
    }
  }

  Future<void> selectSession(String sessionId) async {
    if (state.activeSessionId != null && state.activeSessionId != sessionId) {
      await cleanupEmptySession(state.activeSessionId);
    }

    state = state.copyWith(activeSessionId: sessionId, isLoading: true);
    try {
      final data = await _sb
          .from('chat_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final newMessages = (data as List)
          .map((j) => ChatMessage.fromJson(j as Map<String, dynamic>))
          .toList();

      final others = state.messages.where((m) => m.sessionId != sessionId).toList();
      state = state.copyWith(
        activeSessionId: sessionId,
        messages: [...others, ...newMessages],
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> createNewSession() async {
    if (state.activeSessionId != null) {
      await cleanupEmptySession(state.activeSessionId);
    }

    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now();
    final session = ChatSession(
      id: id,
      userId: userId,
      title: 'New Chat',
      createdAt: now,
    );

    try {
      await _sb.from('chat_sessions').insert(session.toJson());
    } catch (_) {}

    state = state.copyWith(
      sessions: [session, ...state.sessions],
      activeSessionId: session.id,
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Auto-create a session if none active
    if (state.activeSessionId == null) {
      await createNewSession();
    }
    final sessionId = state.activeSessionId!;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      sessionId: sessionId,
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );

    // Update session title on first message
    List<ChatSession> updatedSessions = state.sessions;
    final existingSession = state.sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => ChatSession(
          id: sessionId,
          userId: _sb.auth.currentUser?.id ?? '',
          title: 'New Chat',
          createdAt: DateTime.now()),
    );

    if (existingSession.title == 'New Chat') {
      final newTitle = text.trim().length > 30
          ? '${text.trim().substring(0, 30)}\u2026'
          : text.trim();
      final updated = existingSession.copyWith(title: newTitle);
      updatedSessions = state.sessions
          .map((s) => s.id == sessionId ? updated : s)
          .toList();
      try {
        await _sb
            .from('chat_sessions')
            .update({'title': newTitle}).eq('id', sessionId);
      } catch (_) {}
    }

    state = state.copyWith(
      sessions: updatedSessions,
      messages: [...state.messages, userMsg],
      isSendingMessage: true,
    );

    try {
      await _sb.from('chat_messages').insert(userMsg.toJson());
    } catch (_) {}

    try {
      // Build partner context
      final memoryNotifier = _ref.read(memoryProvider.notifier);
      var memories = memoryNotifier.partnerMemories;
      if (memories.isEmpty) {
        memories = _ref.read(memoryProvider).valueOrNull ?? [];
      }
      final partnerContext = memories.isEmpty
          ? 'No specific memories or preferences recorded yet.'
          : memories.map((m) => '- [${m.category}]: ${m.content}').join('\n');

      // Build history from active messages
      final history = state.activeMessages
          .where((m) => m.id != userMsg.id)
          .toList()
          .take(6)
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final responseText =
          await GroqClient.chat(text.trim(), partnerContext, history);

      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        sessionId: sessionId,
        role: 'ai',
        content: responseText,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isSendingMessage: false,
      );

      try {
        await _sb.from('chat_messages').insert(aiMsg.toJson());
      } catch (_) {}
    } catch (_) {
      final errMsg = ChatMessage(
        id: const Uuid().v4(),
        sessionId: sessionId,
        role: 'ai',
        content: "I couldn't think right now. Try again in a moment \ud83d\udc95",
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errMsg],
        isSendingMessage: false,
      );
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _sb.from('chat_messages').delete().eq('session_id', sessionId);
      await _sb.from('chat_sessions').delete().eq('id', sessionId);
    } catch (_) {}

    final remaining =
        state.sessions.where((s) => s.id != sessionId).toList();
    final remainingMsgs =
        state.messages.where((m) => m.sessionId != sessionId).toList();

    final nextId =
        state.activeSessionId == sessionId && remaining.isNotEmpty
            ? remaining.first.id
            : (state.activeSessionId != sessionId
                ? state.activeSessionId
                : null);

    state = state.copyWith(
      sessions: remaining,
      messages: remainingMsgs,
      activeSessionId: nextId,
    );

    if (nextId != null && state.messages.where((m) => m.sessionId == nextId).isEmpty) {
      await selectSession(nextId);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final chatSessionsProvider =
    StateNotifierProvider<ChatSessionsNotifier, ChatSessionsState>(
        (ref) => ChatSessionsNotifier(ref));
