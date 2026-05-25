import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../providers/chat_sessions_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/pronoun_helper.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSidebar = false;

  @override
  void deactivate() {
    final state = ref.read(chatSessionsProvider);
    ref.read(chatSessionsProvider.notifier).cleanupEmptySession(state.activeSessionId);
    super.deactivate();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(chatSessionsProvider.notifier).sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('h:mm a').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatSessionsProvider);
    final messages = chatState.activeMessages;
    final tc = ref.watch(themeProvider).colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final pronoun = coupleState?.currentUser?.partnerPronoun ?? 'she';

    if (chatState.isSendingMessage) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: Row(
        children: [
          // ── SIDEBAR ──────────────────────────────────────────────────────
          if (_showSidebar) _buildSidebar(chatState, tc),

          // ── MAIN CHAT AREA ────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _buildAppBar(chatState, tc, pronoun),
                Expanded(
                  child: messages.isEmpty && chatState.activeSessionId == null
                      ? _buildQuickPrompts(tc, pronoun)
                      : messages.isEmpty
                          ? _buildEmptySessionHint(tc)
                          : _buildMessageList(messages, chatState, tc),
                ),
                _buildInputRow(chatState.isSendingMessage, tc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(ChatSessionsState chatState, ThemeColors tc, String pronoun) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: tc.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: tc.textPrimary, size: 20),
              onPressed: () => context.go('/home'),
            ),
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: _showSidebar ? tc.iconColor : tc.textMuted,
                size: 22,
              ),
              onPressed: () => setState(() => _showSidebar = !_showSidebar),
              tooltip: 'Chat history',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatState.sessions
                        .firstWhere(
                          (s) => s.id == chatState.activeSessionId,
                          orElse: () => ChatSession(
                            id: '',
                            userId: '',
                            title: 'AI Companion ✨',
                            createdAt: DateTime.now(),
                          ),
                        )
                        .title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: tc.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Knows ${PronounHelper.object(pronoun).toLowerCase()} better than anyone',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: tc.iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_comment_rounded,
                  color: tc.iconColor, size: 22),
              onPressed: () {
                ref.read(chatSessionsProvider.notifier).createNewSession();
                setState(() => _showSidebar = false);
              },
              tooltip: 'New chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(ChatSessionsState chatState, ThemeColors tc) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: tc.cardColor,
        border: Border(
          right: BorderSide(
            color: tc.borderColor,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chat History',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: tc.textMuted, size: 20),
                    onPressed: () => setState(() => _showSidebar = false),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tc.iconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () {
                  ref.read(chatSessionsProvider.notifier).startNewChat();
                  setState(() => _showSidebar = false);
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('New Chat', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: tc.borderColor),
            const SizedBox(height: 4),

            // Sessions list
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.sessions.isEmpty
                      ? Center(
                          child: Text(
                            'No chats yet.\nStart a new one!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                                fontSize: 13, color: tc.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: chatState.sessions.length,
                          itemBuilder: (context, index) {
                            final session = chatState.sessions[index];
                            final isActive =
                                session.id == chatState.activeSessionId;
                            final isEmpty = isActive && chatState.activeMessages.isEmpty;
                            return _buildSessionTile(session, isActive, isEmpty, tc);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(ChatSession session, bool isActive, bool isEmpty, ThemeColors tc) {
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.redAccent.withValues(alpha: 0.1),
        child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
      ),
      confirmDismiss: (_) async {
        if (isEmpty) return true;
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: tc.cardColor,
            title: Text('Delete chat?',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.bold, color: tc.textPrimary)),
            content: Text('This conversation will be permanently deleted.',
                style: GoogleFonts.dmSans(color: tc.textSecondary)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        ref.read(chatSessionsProvider.notifier).deleteSession(session.id);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(chatSessionsProvider.notifier).selectSession(session.id);
            setState(() => _showSidebar = false);
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? tc.iconColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(
                      color: tc.iconColor.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: isActive ? tc.iconColor : tc.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive ? tc.textPrimary : tc.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat.MMMd().format(session.createdAt),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: tc.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: tc.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    if (isEmpty) {
                      ref.read(chatSessionsProvider.notifier).deleteSession(session.id);
                    } else {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: tc.cardColor,
                          title: Text('Delete chat?',
                              style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold, color: tc.textPrimary)),
                          content: Text('This conversation will be permanently deleted.',
                              style: GoogleFonts.dmSans(color: tc.textSecondary)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(chatSessionsProvider.notifier).deleteSession(session.id);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySessionHint(ThemeColors tc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✨', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything.',
            style: GoogleFonts.dmSans(fontSize: 13, color: tc.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
      List<ChatMessage> messages, ChatSessionsState chatState, ThemeColors tc) {
    final reversedMessages = messages.reversed.toList();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      reverse: true,
      itemCount: reversedMessages.length + (chatState.isSendingMessage ? 1 : 0),
      itemBuilder: (context, index) {
        if (chatState.isSendingMessage && index == 0) {
          return _TypingIndicator(tc: tc);
        }
        final actualIndex = chatState.isSendingMessage ? index - 1 : index;
        final msg = reversedMessages[actualIndex];
        final isUser = msg.role == 'user';
        return _buildMessageBubble(msg, isUser, tc);
      },
    );
  }

  Widget _buildQuickPrompts(ThemeColors tc, String pronoun) {
    final prompts = [
      "What should I cook for ${PronounHelper.object(pronoun).toLowerCase()} tonight? 🍳",
      "${PronounHelper.subject(pronoun)} had a tough week — what can I do? 💡",
      "Suggest a date idea under ₹1500 🍷",
      "What does ${PronounHelper.subject(pronoun).toLowerCase()} usually crave?",
      "${PronounHelper.possessive(pronoun)} period is soon — how can I care better?",
      "Gift idea under ₹1500 🎁",
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Text('✨', style: TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              "How can I help you care for ${PronounHelper.object(pronoun).toLowerCase()} today?",
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: tc.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Select a quick prompt or ask anything.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: tc.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 36),
          ...prompts.map((p) {
            return GestureDetector(
              onTap: () {
                ref.read(chatSessionsProvider.notifier).sendMessage(p);
                _scrollToBottom();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: tc.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: tc.borderColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: tc.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: tc.iconColor,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isUser, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: tc.iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('✨', style: TextStyle(fontSize: 14)),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? tc.iconColor
                        : tc.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: tc.borderColor),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: tc.iconColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    msg.content,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: isUser ? Colors.white : tc.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    _formatTime(msg.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: tc.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(bool isLoading, ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tc.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: tc.inputFillColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: tc.borderColor),
                ),
                child: TextField(
                  controller: _textController,
                  style: GoogleFonts.dmSans(color: tc.textPrimary),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything...',
                    hintStyle: GoogleFonts.dmSans(
                        color: tc.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: (isLoading || _textController.text.trim().isEmpty)
                  ? null
                  : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isLoading || _textController.text.trim().isEmpty)
                      ? tc.borderColor
                      : tc.iconColor,
                  shape: BoxShape.circle,
                  boxShadow: (isLoading ||
                          _textController.text.trim().isEmpty)
                      ? null
                      : [
                          BoxShadow(
                            color: tc.iconColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  final int delayMs;
  final ThemeColors tc;
  const _TypingDot({required this.delayMs, required this.tc});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.tc.iconColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.tc});
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, top: 4),
            decoration: BoxDecoration(
              color: tc.iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('✨', style: TextStyle(fontSize: 14)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tc.cardColor,
              border: Border.all(color: tc.borderColor),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delayMs: 0, tc: tc),
                const SizedBox(width: 6),
                _TypingDot(delayMs: 150, tc: tc),
                const SizedBox(width: 6),
                _TypingDot(delayMs: 300, tc: tc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
