/// A "Drop" — an emotional photo moment shared within a couple.
/// Stored in the `drops` table.
class DropModel {
  final String id;
  final String coupleId;
  final String addedBy;
  final String photoUrl;
  final String? caption;
  final String? songTitle;
  final String? songArtist;
  final String? songInfo;
  final String visibility;  // 'private' | 'partner_visible' | 'shared'
  final int importanceScore;
  final List<String> momentContext;
  final DateTime createdAt;

  DropModel({
    required this.id,
    required this.coupleId,
    required this.addedBy,
    required this.photoUrl,
    this.caption,
    this.songTitle,
    this.songArtist,
    this.songInfo,
    this.visibility = 'shared',
    this.importanceScore = 0,
    this.momentContext = const [],
    required this.createdAt,
  });

  factory DropModel.fromJson(Map<String, dynamic> json) {
    return DropModel(
      id:              json['id'] as String,
      coupleId:        json['couple_id'] as String,
      addedBy:         json['added_by'] as String,
      photoUrl:        json['photo_url'] as String,
      caption:         json['caption'] as String?,
      songTitle:       json['song_title'] as String?,
      songArtist:      json['song_artist'] as String?,
      songInfo:        json['song_info'] as String?,
      visibility:      json['visibility'] as String? ?? 'shared',
      importanceScore: json['importance_score'] as int? ?? 0,
      momentContext:   (json['moment_context'] as List?)?.map((e) => e as String).toList() ?? [],
      createdAt:       DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':               id,
      'couple_id':        coupleId,
      'added_by':         addedBy,
      'photo_url':        photoUrl,
      'visibility':       visibility,
      'importance_score': importanceScore,
      'moment_context':   momentContext,
      'created_at':       createdAt.toUtc().toIso8601String(),
      if (caption != null)    'caption':     caption,
      if (songTitle != null)  'song_title':  songTitle,
      if (songArtist != null) 'song_artist': songArtist,
      if (songInfo != null)   'song_info':   songInfo,
    };
  }

  DropModel copyWith({
    String? id,
    String? coupleId,
    String? addedBy,
    String? photoUrl,
    String? caption,
    String? songTitle,
    String? songArtist,
    String? songInfo,
    String? visibility,
    int? importanceScore,
    List<String>? momentContext,
    DateTime? createdAt,
  }) {
    return DropModel(
      id:              id              ?? this.id,
      coupleId:        coupleId        ?? this.coupleId,
      addedBy:         addedBy         ?? this.addedBy,
      photoUrl:        photoUrl        ?? this.photoUrl,
      caption:         caption         ?? this.caption,
      songTitle:       songTitle       ?? this.songTitle,
      songArtist:      songArtist      ?? this.songArtist,
      songInfo:        songInfo        ?? this.songInfo,
      visibility:      visibility      ?? this.visibility,
      importanceScore: importanceScore ?? this.importanceScore,
      momentContext:   momentContext   ?? this.momentContext,
      createdAt:       createdAt       ?? this.createdAt,
    );
  }
}
