class JournalEntryModel {
  final String id;
  final String userId;
  final String? title;
  final String content;
  final String? mood;
  final String visibility;
  final DateTime createdAt;
  final bool isPinned; // Local preference/or future table ready, can default to false

  JournalEntryModel({
    required this.id,
    required this.userId,
    this.title,
    required this.content,
    this.mood,
    this.visibility = 'private',
    required this.createdAt,
    this.isPinned = false,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json, {bool isPinned = false}) => JournalEntryModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String?,
        content: json['content'] as String,
        mood: json['mood'] as String?,
        visibility: json['visibility'] as String? ?? 'private',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        isPinned: isPinned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'mood': mood,
        'visibility': visibility,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  JournalEntryModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? mood,
    String? visibility,
    DateTime? createdAt,
    bool? isPinned,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
