// lib/core/models/category.dart

class Category {
  final String id;
  final String name;
  final int displayOrder;
  final List<CategoryItem> items;

  const Category({
    required this.id,
    required this.name,
    required this.displayOrder,
    this.items = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['_id'] as String,
        name: json['name'] as String,
        displayOrder: json['displayOrder'] as int? ?? 0,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// Item rút gọn dùng trong context trang quán (khách xem menu).
// MenuItem đầy đủ hơn nằm trong menu_provider.dart (dashboard quán).
class CategoryItem {
  final String id;
  final String name;
  final String? description;
  final int price;
  final List<String> images;
  final int? stock;       // null = không quản lý kho
  final String status;   // active | closed | paused

  const CategoryItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.images,
    this.stock,
    required this.status,
  });

  bool get isAvailable => status == 'active' && stock != 0;

  String? get primaryImage => images.isNotEmpty ? images.first : null;

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        id: json['_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: json['price'] as int,
        images: List<String>.from(json['images'] as List? ?? []),
        stock: json['stock'] as int?,
        status: json['status'] as String? ?? 'active',
      );
}

// lib/core/models/category.dart