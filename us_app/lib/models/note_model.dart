class NoteModel {
  final String id;
  final String coupleId;
  final String addedBy;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.coupleId,
    required this.addedBy,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.createdAt,
  });



  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
        id:        j['id'] as String,
        coupleId:  j['couple_id'] as String,
        addedBy:   j['added_by'] as String,
        title:     j['title'] as String,
        content:   j['content'] as String,
        isPinned:  j['pinned'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'couple_id':  coupleId,
        'added_by':   addedBy,
        'title':      title,
        'content':    content,
        'pinned':  isPinned,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
