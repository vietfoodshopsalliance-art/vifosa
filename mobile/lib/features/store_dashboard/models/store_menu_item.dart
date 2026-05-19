// lib/features/store_dashboard/models/store_menu_item.dart

class StoreCategory {
  final String id;
  final String name;
  final int displayOrder;
  final List<StoreMenuItem> items;

  const StoreCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.items,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) => StoreCategory(
        id: (json['_id'] ?? json['id']) as String,
        name: json['name'] as String,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List? ?? [])
            .map((e) => StoreMenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StoreMenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final int? stock;
  final String status; // 'active' | 'paused' | 'closed'
  final String? categoryId;

  const StoreMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    this.stock,
    required this.status,
    this.categoryId,
  });

  bool get isOutOfStock => stock != null && stock! <= 0;

  factory StoreMenuItem.fromJson(Map<String, dynamic> json) => StoreMenuItem(
        id: (json['_id'] ?? json['id']) as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        images: List<String>.from(json['images'] as List? ?? []),
        stock: (json['stock'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'active',
        categoryId: (json['categoryId'] ?? json['category']) as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'images': images,
        if (stock != null) 'stock': stock,
        'status': status,
        if (categoryId != null) 'categoryId': categoryId,
      };

  StoreMenuItem copyWith({
    String? name,
    String? description,
    double? price,
    List<String>? images,
    int? stock,
    String? status,
    String? categoryId,
  }) =>
      StoreMenuItem(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        images: images ?? this.images,
        stock: stock ?? this.stock,
        status: status ?? this.status,
        categoryId: categoryId ?? this.categoryId,
      );
}
// lib/features/store_dashboard/models/store_menu_item.dart