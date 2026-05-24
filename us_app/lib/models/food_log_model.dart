class FoodLogModel {
  static const mealBreakfast = 'breakfast';
  static const mealLunch     = 'lunch';
  static const mealDinner    = 'dinner';
  static const mealSnack     = 'snack';

  static const moodHappy    = 'happy';
  static const moodTired    = 'tired';
  static const moodStressed = 'stressed';
  static const moodOkay     = 'okay';
  static const moodSick     = 'sick';

  final String   id;
  final String   userId;
  final String   description;
  final String?  photoUrl;
  final int?     calories;
  final String   mealType;
  final String?  mood;
  final DateTime loggedAt;

  FoodLogModel({
    required this.id,
    required this.userId,
    required this.description,
    this.photoUrl,
    this.calories,
    required this.mealType,
    this.mood,
    required this.loggedAt,
  });

  String get mealEmoji {
    switch (mealType) {
      case mealBreakfast: return '🌅';
      case mealLunch:     return '☀️';
      case mealDinner:    return '🌙';
      default:            return '🍪';
    }
  }

  String get mealLabel {
    switch (mealType) {
      case mealBreakfast: return 'Breakfast';
      case mealLunch:     return 'Lunch';
      case mealDinner:    return 'Dinner';
      default:            return 'Snack';
    }
  }

  String get moodEmoji {
    switch (mood) {
      case moodHappy:    return '😊';
      case moodTired:    return '😴';
      case moodStressed: return '😟';
      case moodSick:     return '🤒';
      case moodOkay:     return '🙂';
      default:           return '';
    }
  }

  factory FoodLogModel.fromJson(Map<String, dynamic> j) => FoodLogModel(
        id:          j['id'] as String,
        userId:      j['user_id'] as String,
        description: j['description'] as String? ?? '',
        photoUrl:    j['photo_url'] as String?,
        calories:    j['calories'] as int?,
        mealType:    j['meal_type'] as String,
        mood:        j['mood'] as String?,
        loggedAt:    DateTime.parse(j['logged_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'user_id':     userId,
        'description': description,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (calories != null) 'calories':  calories,
        'meal_type':   mealType,
        if (mood != null) 'mood': mood,
        'logged_at':   loggedAt.toUtc().toIso8601String(),
      };
}
