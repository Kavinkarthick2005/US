class WishlistModel {
  static const typeBuy        = 'buy';
  static const typeExperience = 'experience';

  final String   id;
  final String   coupleId;
  final String   addedBy;
  final String   title;
  final String?  description;
  final String?  category;
  final String?  priority;
  final String   type;
  final double?  price;
  final String?  link;
  final String?  imageUrl;
  final bool     isDone;
  final bool     isHidden;
  final DateTime createdAt;

  WishlistModel({
    required this.id,
    required this.coupleId,
    required this.addedBy,
    required this.title,
    this.description,
    this.category,
    this.priority,
    required this.type,
    this.price,
    this.link,
    this.imageUrl,
    required this.isDone,
    this.isHidden = false,
    required this.createdAt,
  });

  factory WishlistModel.fromJson(Map<String, dynamic> j) => WishlistModel(
        id:          j['id'] as String,
        coupleId:    j['couple_id'] as String,
        addedBy:     j['added_by'] as String,
        title:       j['title'] as String,
        description: j['description'] as String?,
        category:    j['category'] as String?,
        priority:    j['priority'] as String?,
        type:        j['type'] as String,
        price:       (j['price'] as num?)?.toDouble(),
        link:        j['link'] as String?,
        imageUrl:    j['image_url'] as String?,
        isDone:      j['is_done'] as bool? ?? false,
        isHidden:    j['is_hidden'] as bool? ?? false,
        createdAt:   DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'couple_id':   coupleId,
        'added_by':    addedBy,
        'title':       title,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (priority != null && priority!.isNotEmpty) 'priority': priority,
        'type':        type,
        if (price != null) 'price': price,
        if (link  != null && link!.isNotEmpty)  'link':  link,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
        'is_done':     isDone,
        'is_hidden':   isHidden,
        'created_at':  createdAt.toUtc().toIso8601String(),
      };
}
