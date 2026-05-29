/// V2 MemoryModel — extended with space, partnerCare, song, visibility and coupleId.
class MemoryModel {
  final String id;
  final String ownerId;
  final String addedBy;
  final String category;
  final String content;
  final DateTime createdAt;
  // V2 fields
  final String? coupleId;
  final String? imageUrl;
  final String visibility;       // 'private' | 'partner_visible' | 'shared'
  final String space;            // 'he' | 'she' | 'us'
  final bool isPartnerCare;      // true = about partner (Partner Care feature)
  final String? songTitle;
  final String? songArtist;

  MemoryModel({
    required this.id,
    required this.ownerId,
    required this.addedBy,
    required this.category,
    required this.content,
    required this.createdAt,
    this.coupleId,
    this.imageUrl,
    this.visibility = 'shared',
    this.space = 'us',
    this.isPartnerCare = false,
    this.songTitle,
    this.songArtist,
  });

  factory MemoryModel.fromJson(Map<String, dynamic> json) {
    return MemoryModel(
      id:            json['id'] as String,
      ownerId:       json['owner_id'] as String,
      addedBy:       json['added_by'] as String,
      category:      json['category'] as String? ?? 'general',
      content:       json['content'] as String? ?? '',
      createdAt:     DateTime.parse(json['created_at'] as String).toLocal(),
      coupleId:      json['couple_id'] as String?,
      imageUrl:      json['image_url'] as String?,
      visibility:    json['visibility'] as String? ?? 'shared',
      space:         json['space'] as String? ?? 'us',
      isPartnerCare: json['is_partner_care'] as bool? ?? false,
      songTitle:     json['song_title'] as String?,
      songArtist:    json['song_artist'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':              id,
      'owner_id':        ownerId,
      'added_by':        addedBy,
      'category':        category,
      'content':         content,
      'created_at':      createdAt.toUtc().toIso8601String(),
      if (coupleId != null) 'couple_id': coupleId,
      if (imageUrl != null) 'image_url': imageUrl,
      'visibility':      visibility,
      'space':           space,
      'is_partner_care': isPartnerCare,
      if (songTitle != null)  'song_title':  songTitle,
      if (songArtist != null) 'song_artist': songArtist,
    };
  }

  MemoryModel copyWith({
    String? id,
    String? ownerId,
    String? addedBy,
    String? category,
    String? content,
    DateTime? createdAt,
    String? coupleId,
    String? imageUrl,
    String? visibility,
    String? space,
    bool? isPartnerCare,
    String? songTitle,
    String? songArtist,
  }) {
    return MemoryModel(
      id:            id            ?? this.id,
      ownerId:       ownerId       ?? this.ownerId,
      addedBy:       addedBy       ?? this.addedBy,
      category:      category      ?? this.category,
      content:       content       ?? this.content,
      createdAt:     createdAt     ?? this.createdAt,
      coupleId:      coupleId      ?? this.coupleId,
      imageUrl:      imageUrl      ?? this.imageUrl,
      visibility:    visibility    ?? this.visibility,
      space:         space         ?? this.space,
      isPartnerCare: isPartnerCare ?? this.isPartnerCare,
      songTitle:     songTitle     ?? this.songTitle,
      songArtist:    songArtist    ?? this.songArtist,
    );
  }

  // ── Category constants ────────────────────────────────────────────────────
  static const String catFood     = 'food';
  static const String catPlace    = 'place';
  static const String catMood     = 'mood';
  static const String catHabit    = 'habit';
  static const String catJoke     = 'joke';
  static const String catGift     = 'gift';
  static const String catDislike  = 'dislike';
  static const String catRecipe   = 'recipe';
  static const String catGeneral  = 'general';
  static const String catSong     = 'song';
  static const String catMilestone = 'milestone';

  static const List<String> allCategories = [
    catFood, catPlace, catMood, catHabit,
    catJoke, catGift, catDislike, catRecipe,
    catGeneral, catSong, catMilestone,
  ];

  static String categoryEmoji(String cat) {
    switch (cat) {
      case catFood:      return '🍕';
      case catPlace:     return '📍';
      case catMood:      return '🎭';
      case catHabit:     return '😊';
      case catJoke:      return '😂';
      case catGift:      return '🎁';
      case catDislike:   return '👎';
      case catRecipe:    return '🍳';
      case catSong:      return '🎵';
      case catMilestone: return '🏆';
      default:           return '💭';
    }
  }

  // ── Space constants ───────────────────────────────────────────────────────
  static const String spaceHe  = 'he';
  static const String spaceShe = 'she';
  static const String spaceUs  = 'us';

  // ── Visibility constants ──────────────────────────────────────────────────
  static const String visPrivate        = 'private';
  static const String visPartnerVisible = 'partner_visible';
  static const String visShared         = 'shared';
}

class ParsedMemory {
  final String cleanContent;
  final String importance; // 'casual' | 'important' | 'deeply_important'

  ParsedMemory({required this.cleanContent, required this.importance});

  factory ParsedMemory.parse(String content) {
    if (content.startsWith('[deeply_important]')) {
      return ParsedMemory(
        cleanContent: content.replaceFirst('[deeply_important]', '').trim(),
        importance: 'deeply_important',
      );
    } else if (content.startsWith('[important]')) {
      return ParsedMemory(
        cleanContent: content.replaceFirst('[important]', '').trim(),
        importance: 'important',
      );
    } else if (content.startsWith('[casual]')) {
      return ParsedMemory(
        cleanContent: content.replaceFirst('[casual]', '').trim(),
        importance: 'casual',
      );
    }
    return ParsedMemory(cleanContent: content, importance: 'casual');
  }
}
