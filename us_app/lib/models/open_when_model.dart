class OpenWhenModel {
  final String id;
  final String coupleId;
  final String writtenBy;
  final String forPartner;
  final String triggerLabel;
  final String content;
  final bool isOpened;
  final DateTime? openedAt;
  final String coverColor;
  final DateTime createdAt;

  OpenWhenModel({
    required this.id,
    required this.coupleId,
    required this.writtenBy,
    required this.forPartner,
    required this.triggerLabel,
    required this.content,
    this.isOpened = false,
    this.openedAt,
    this.coverColor = '#E8607A',
    required this.createdAt,
  });

  factory OpenWhenModel.fromJson(Map<String, dynamic> json) {
    return OpenWhenModel(
      id:           json['id'] as String,
      coupleId:     json['couple_id'] as String,
      writtenBy:    json['written_by'] as String,
      forPartner:   json['for_partner'] as String,
      triggerLabel: json['trigger_label'] as String,
      content:      json['content'] as String,
      isOpened:     json['is_opened'] as bool? ?? false,
      openedAt:     json['opened_at'] != null
          ? DateTime.parse(json['opened_at'] as String).toLocal()
          : null,
      coverColor:   json['cover_color'] as String? ?? '#E8607A',
      createdAt:    DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':            id,
      'couple_id':     coupleId,
      'written_by':    writtenBy,
      'for_partner':   forPartner,
      'trigger_label': triggerLabel,
      'content':       content,
      'is_opened':     isOpened,
      'cover_color':   coverColor,
      'created_at':    createdAt.toUtc().toIso8601String(),
      if (openedAt != null) 'opened_at': openedAt!.toUtc().toIso8601String(),
    };
  }

  OpenWhenModel copyWith({
    String? id,
    String? coupleId,
    String? writtenBy,
    String? forPartner,
    String? triggerLabel,
    String? content,
    bool? isOpened,
    DateTime? openedAt,
    String? coverColor,
    DateTime? createdAt,
  }) {
    return OpenWhenModel(
      id:           id           ?? this.id,
      coupleId:     coupleId     ?? this.coupleId,
      writtenBy:    writtenBy    ?? this.writtenBy,
      forPartner:   forPartner   ?? this.forPartner,
      triggerLabel: triggerLabel ?? this.triggerLabel,
      content:      content      ?? this.content,
      isOpened:     isOpened     ?? this.isOpened,
      openedAt:     openedAt     ?? this.openedAt,
      coverColor:   coverColor   ?? this.coverColor,
      createdAt:    createdAt    ?? this.createdAt,
    );
  }

  static const List<String> triggerPresets = [
    'When you miss me 💕',
    'When you\'re sad 😢',
    'When you\'re stressed 😤',
    'On your birthday 🎂',
    'When you need a smile 😊',
    'When you\'re proud of yourself 🌟',
    'On our anniversary 💑',
    'When you can\'t sleep 🌙',
    'When you need courage 💪',
    'When everything feels hard 🌧',
  ];
}
