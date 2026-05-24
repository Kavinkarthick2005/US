class MemoryModel {
  final String id;
  final String ownerId;
  final String addedBy;
  final String category;
  final String content;
  final DateTime createdAt;

  MemoryModel({
    required this.id,
    required this.ownerId,
    required this.addedBy,
    required this.category,
    required this.content,
    required this.createdAt,
  });

  factory MemoryModel.fromJson(Map<String, dynamic> json) {
    return MemoryModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      addedBy: json['added_by'] as String,
      category: json['category'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'added_by': addedBy,
      'category': category,
      'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  MemoryModel copyWith({
    String? id,
    String? ownerId,
    String? addedBy,
    String? category,
    String? content,
    DateTime? createdAt,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      addedBy: addedBy ?? this.addedBy,
      category: category ?? this.category,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const String catFood = 'food';
  static const String catPlace = 'place';
  static const String catMood = 'mood';
  static const String catHabit = 'habit';
  static const String catJoke = 'joke';
  static const String catDislike = 'dislike';
  static const String catRecipe = 'recipe';
  static const String catGeneral = 'general';
}
