class ReminderModel {
  final String id;
  final String userId;
  final String remindTo;
  final String title;
  final DateTime remindAt;
  final String repeatType;
  final String category;
  final bool isActive;
  final DateTime createdAt;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.remindTo,
    required this.title,
    required this.remindAt,
    required this.repeatType,
    required this.category,
    required this.isActive,
    required this.createdAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      remindTo: json['remind_to'] as String,
      title: json['title'] as String,
      remindAt: DateTime.parse(json['remind_at'] as String).toLocal(),
      repeatType: json['repeat_type'] as String? ?? repeatNone,
      category: json['category'] as String? ?? catCustom,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'remind_to': remindTo,
      'title': title,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'repeat_type': repeatType,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  String get emoji {
    switch (category) {
      case catPeriod: return '🩸';
      case catFood: return '🍽';
      case catMedicine: return '💊';
      case catDate: return '💕';
      case catHydration: return '💧';
      case catCustom:
      default: return '✏️';
    }
  }

  // Repeat types
  static const String repeatNone = 'none';
  static const String repeatDaily = 'daily';
  static const String repeatWeekly = 'weekly';
  static const String repeatMonthly = 'monthly';

  // Categories
  static const String catPeriod = 'period';
  static const String catFood = 'food';
  static const String catMedicine = 'medicine';
  static const String catDate = 'date';
  static const String catHydration = 'hydration';
  static const String catCustom = 'custom';
}
