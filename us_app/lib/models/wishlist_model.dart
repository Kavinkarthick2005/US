class WishlistModel {
  static const typeBuy        = 'buy';
  static const typeExperience = 'experience';

  final String   id;
  final String   coupleId;
  final String   addedBy;
  final String   title;
  final String   type;
  final double?  price;
  final String?  link;
  final String?  notes;
  final bool     isDone;
  final DateTime createdAt;

  WishlistModel({
    required this.id,
    required this.coupleId,
    required this.addedBy,
    required this.title,
    required this.type,
    this.price,
    this.link,
    this.notes,
    required this.isDone,
    required this.createdAt,
  });



  factory WishlistModel.fromJson(Map<String, dynamic> j) => WishlistModel(
        id:        j['id'] as String,
        coupleId:  j['couple_id'] as String,
        addedBy:   j['added_by'] as String,
        title:     j['title'] as String,
        type:      j['type'] as String,
        price:     (j['price'] as num?)?.toDouble(),
        link:      j['link'] as String?,
        notes:     j['notes'] as String?,
        isDone:    j['is_done'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'couple_id':  coupleId,
        'added_by':   addedBy,
        'title':      title,
        'type':       type,
        if (price != null) 'price': price,
        if (link  != null && link!.isNotEmpty)  'link':  link,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'is_done':    isDone,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
