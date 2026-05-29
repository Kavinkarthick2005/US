class SongModel {
  final String id;
  final String coupleId;
  final String addedBy;
  final String title;
  final String artist;
  final String? album;
  final String? spotifyUrl;
  final String? appleMusicUrl;
  final String? youtubeUrl;
  final String category;
  final String? memoryId;
  final String? notes;
  final DateTime createdAt;

  SongModel({
    required this.id,
    required this.coupleId,
    required this.addedBy,
    required this.title,
    required this.artist,
    this.album,
    this.spotifyUrl,
    this.appleMusicUrl,
    this.youtubeUrl,
    this.category = 'our_songs',
    this.memoryId,
    this.notes,
    required this.createdAt,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id:            json['id'] as String,
      coupleId:      json['couple_id'] as String,
      addedBy:       json['added_by'] as String,
      title:         json['title'] as String,
      artist:        json['artist'] as String,
      album:         json['album'] as String?,
      spotifyUrl:    json['spotify_url'] as String?,
      appleMusicUrl: json['apple_music_url'] as String?,
      youtubeUrl:    json['youtube_url'] as String?,
      category:      json['category'] as String? ?? 'our_songs',
      memoryId:      json['memory_id'] as String?,
      notes:         json['notes'] as String?,
      createdAt:     DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':              id,
      'couple_id':       coupleId,
      'added_by':        addedBy,
      'title':           title,
      'artist':          artist,
      'album':           album,
      'spotify_url':     spotifyUrl,
      'apple_music_url': appleMusicUrl,
      'youtube_url':     youtubeUrl,
      'category':        category,
      'memory_id':       memoryId,
      'notes':           notes,
      'created_at':      createdAt.toUtc().toIso8601String(),
    };
  }

  SongModel copyWith({
    String? id,
    String? coupleId,
    String? addedBy,
    String? title,
    String? artist,
    String? album,
    String? spotifyUrl,
    String? appleMusicUrl,
    String? youtubeUrl,
    String? category,
    String? memoryId,
    String? notes,
    DateTime? createdAt,
  }) {
    return SongModel(
      id:            id            ?? this.id,
      coupleId:      coupleId      ?? this.coupleId,
      addedBy:       addedBy       ?? this.addedBy,
      title:         title         ?? this.title,
      artist:        artist        ?? this.artist,
      album:         album         ?? this.album,
      spotifyUrl:    spotifyUrl    ?? this.spotifyUrl,
      appleMusicUrl: appleMusicUrl ?? this.appleMusicUrl,
      youtubeUrl:    youtubeUrl    ?? this.youtubeUrl,
      category:      category      ?? this.category,
      memoryId:      memoryId      ?? this.memoryId,
      notes:         notes         ?? this.notes,
      createdAt:     createdAt     ?? this.createdAt,
    );
  }

  // Pre-defined categories for UI presentation
  static const List<Map<String, dynamic>> predefinedCategories = [
    {'id': 'our_songs',     'label': 'Our Songs 💑',         'color': '#E8607A'},
    {'id': 'feels_like_us', 'label': 'Feels Like Us 🌅',      'color': '#C97B93'},
    {'id': 'she_loves',     'label': 'She Loves 💕',          'color': '#F4A3B3'},
    {'id': 'reminds_me',    'label': 'Reminds Me of Her 🌸', 'color': '#D4AF37'},
    {'id': 'late_night',    'label': 'Late Night 🌙',        'color': '#1A0A0F'},
    {'id': 'drive',         'label': 'Drive 🚗',             'color': '#E6A817'},
    {'id': 'study',         'label': 'Study Together 📚',    'color': '#7A9E7E'},
    {'id': 'rainy',         'label': 'Rainy Days 🌧',        'color': '#5A7090'},
  ];
}
