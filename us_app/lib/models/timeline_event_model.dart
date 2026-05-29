import 'package:flutter/material.dart';

/// A unified event for the Relationship Timeline.
/// Aggregated from memories, drops, and open-when letters.
class TimelineEvent {
  final String id;
  final TimelineEventType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime eventDate;
  final String? category;       // For memory events
  final String? songTitle;      // For memory/drop events
  final String? songArtist;
  final bool isOpened;          // For open-when events
  final String? addedBy;        // Profile ID of who created this

  TimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    required this.eventDate,
    this.category,
    this.songTitle,
    this.songArtist,
    this.isOpened = false,
    this.addedBy,
  });

  /// Creates a TimelineEvent from a MemoryModel-like map.
  factory TimelineEvent.fromMemory(Map<String, dynamic> json) {
    final cat = json['category'] as String? ?? 'general';
    return TimelineEvent(
      id:          json['id'] as String,
      type:        TimelineEventType.memory,
      title:       json['content'] as String? ?? '',
      description: cat,
      imageUrl:    json['image_url'] as String?,
      eventDate:   DateTime.parse(json['created_at'] as String).toLocal(),
      category:    cat,
      songTitle:   json['song_title'] as String?,
      songArtist:  json['song_artist'] as String?,
      addedBy:     json['added_by'] as String?,
    );
  }

  /// Creates a TimelineEvent from a DropModel-like map.
  factory TimelineEvent.fromDrop(Map<String, dynamic> json) {
    return TimelineEvent(
      id:          json['id'] as String,
      type:        TimelineEventType.drop,
      title:       json['caption'] as String? ?? 'A moment',
      imageUrl:    json['photo_url'] as String?,
      eventDate:   DateTime.parse(json['created_at'] as String).toLocal(),
      songTitle:   json['song_title'] as String?,
      songArtist:  json['song_artist'] as String?,
      addedBy:     json['added_by'] as String?,
    );
  }

  /// Creates a TimelineEvent from an OpenWhenModel-like map.
  factory TimelineEvent.fromOpenWhen(Map<String, dynamic> json) {
    return TimelineEvent(
      id:          json['id'] as String,
      type:        TimelineEventType.openWhen,
      title:       json['trigger_text'] as String? ?? 'A letter',
      description: json['is_opened'] as bool? ?? false
          ? 'Opened'
          : 'Sealed',
      eventDate:   DateTime.parse(json['created_at'] as String).toLocal(),
      isOpened:    json['is_opened'] as bool? ?? false,
      addedBy:     json['added_by'] as String?,
    );
  }
}

enum TimelineEventType {
  memory,
  drop,
  openWhen,
  milestone,
}

extension TimelineEventTypeX on TimelineEventType {
  String get label {
    switch (this) {
      case TimelineEventType.memory:    return 'Memory';
      case TimelineEventType.drop:      return 'Drop';
      case TimelineEventType.openWhen:  return 'Letter';
      case TimelineEventType.milestone: return 'Milestone';
    }
  }

  String get emoji {
    switch (this) {
      case TimelineEventType.memory:    return '💭';
      case TimelineEventType.drop:      return '📸';
      case TimelineEventType.openWhen:  return '💌';
      case TimelineEventType.milestone: return '🏆';
    }
  }

  Color get color {
    switch (this) {
      case TimelineEventType.memory:    return const Color(0xFFE8607A);
      case TimelineEventType.drop:      return const Color(0xFFD4AF37);
      case TimelineEventType.openWhen:  return const Color(0xFFC97B93);
      case TimelineEventType.milestone: return const Color(0xFF4CAF7D);
    }
  }
}
