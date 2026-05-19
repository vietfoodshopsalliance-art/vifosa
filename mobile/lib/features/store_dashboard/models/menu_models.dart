// mobile/lib/features/store_dashboard/models/menu_models.dart

class MenuCategory {
  final String id;
  final String storeId;
  final String name;
  final int displayOrder;
  final List<MenuItem> items;

  const MenuCategory({
    required this.id,
    required this.storeId,
    required this.name,
    required this.displayOrder,
    this.items = const [],
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['_id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MenuItem {
  final String id;
  final String storeId;
  final String categoryId;
  final String name;
  final String description;
  final int price;
  final List<String> images;
  final int? stock; // null = không quản lý
  final String status; // active | closed | paused
  final SoldCount soldCount;

  const MenuItem({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    this.stock,
    required this.status,
    required this.soldCount,
  });

  bool get isOutOfStock => stock != null && stock! <= 0;
  bool get isVisible => status == 'active' && !isOutOfStock;

  String get thumbnailUrl {
    if (images.isEmpty) return '';
    return _cloudinaryTransform(images.first, 'w_400,f_auto,q_auto');
  }

  String get detailUrl {
    if (images.isEmpty) return '';
    return _cloudinaryTransform(images.first, 'w_800,f_auto,q_auto');
  }

  /// Thêm transform vào Cloudinary URL
  static String _cloudinaryTransform(String url, String transform) {
    // URL dạng: https://res.cloudinary.com/{cloud}/image/upload/{transform}/{public_id}
    return url.replaceFirst('/image/upload/', '/image/upload/$transform/');
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['_id'] as String,
      storeId: json['storeId'] as String? ?? '',
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toInt(),
      images: List<String>.from(json['images'] as List? ?? []),
      stock: json['stock'] as int?,
      status: json['status'] as String,
      soldCount: SoldCount.fromJson(json['soldCount'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class SoldCount {
  final int allTime;
  final int last7d;
  final int last30d;
  final int last365d;

  const SoldCount({
    this.allTime = 0,
    this.last7d = 0,
    this.last30d = 0,
    this.last365d = 0,
  });

  factory SoldCount.fromJson(Map<String, dynamic> json) {
    return SoldCount(
      allTime: (json['allTime'] as num?)?.toInt() ?? 0,
      last7d: (json['last7d'] as num?)?.toInt() ?? 0,
      last30d: (json['last30d'] as num?)?.toInt() ?? 0,
      last365d: (json['last365d'] as num?)?.toInt() ?? 0,
    );
  }
}