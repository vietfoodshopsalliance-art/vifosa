// lib/core/models/menu_item.dart

class SoldCount {
  final int allTime;
  final int last7d;
  final int last30d;
  final int last365d;

  const SoldCount({
    required this.allTime,
    required this.last7d,
    required this.last30d,
    required this.last365d,
  });

  factory SoldCount.fromJson(Map<String, dynamic> json) => SoldCount(
        allTime: (json['allTime'] as num?)?.toInt() ?? 0,
        last7d: (json['last7d'] as num?)?.toInt() ?? 0,
        last30d: (json['last30d'] as num?)?.toInt() ?? 0,
        last365d: (json['last365d'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'allTime': allTime,
        'last7d': last7d,
        'last30d': last30d,
        'last365d': last365d,
      };
}

enum MenuItemStatus { active, closed, paused }

extension MenuItemStatusX on MenuItemStatus {
  String get value => switch (this) {
        MenuItemStatus.active => 'active',
        MenuItemStatus.closed => 'closed',
        MenuItemStatus.paused => 'paused',
      };

  static MenuItemStatus fromString(String? s) => switch (s) {
        'closed' => MenuItemStatus.closed,
        'paused' => MenuItemStatus.paused,
        _ => MenuItemStatus.active,
      };
}

class MenuItem {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final int? stock;
  final MenuItemStatus status;
  final SoldCount soldCount;
  final bool isDeleted;
  final String? likeId;
  final String? imageUrl;
  final String? storeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MenuItem({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    this.stock,
    required this.status,
    required this.soldCount,
    this.isDeleted = false,
    this.likeId,
    this.imageUrl,
    this.storeName,
    this.createdAt,
    this.updatedAt,
  });

  String? get thumbnail => images.isNotEmpty ? images.first : null;

  bool get isAvailable =>
      status == MenuItemStatus.active && !isDeleted && (stock == null || stock! > 0);

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: (json['_id'] ?? json['id'] ?? '') as String,
        storeId: (json['storeId'] is String && json['storeId'] != 'null')
          ? json['storeId'] as String
          : '',
        categoryId: json['categoryId'] as String?,
        name: (json['name'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        images: (json['images'] as List?)?.map((e) => e as String).toList() ?? [],
        stock: json['stock'] == null ? null : (json['stock'] as num).toInt(),
        status: MenuItemStatusX.fromString(json['status'] as String?),
        soldCount: json['soldCount'] != null
            ? SoldCount.fromJson(json['soldCount'] as Map<String, dynamic>)
            : const SoldCount(allTime: 0, last7d: 0, last30d: 0, last365d: 0),
        isDeleted: (json['isDeleted'] as bool?) ?? false,
        likeId: json['likeId'] as String?,
        imageUrl: json['imageUrl'] as String?,
        storeName: json['storeName'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'storeId': storeId,
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'images': images,
        'stock': stock,
        'status': status.value,
        'soldCount': soldCount.toJson(),
        'isDeleted': isDeleted,
        'likeId': likeId,
        'imageUrl': imageUrl,
        'storeName': storeName,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  MenuItem copyWith({
    String? id,
    String? storeId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    List<String>? images,
    int? stock,
    MenuItemStatus? status,
    SoldCount? soldCount,
    bool? isDeleted,
    String? likeId,
    String? imageUrl,
    String? storeName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MenuItem(
        id: id ?? this.id,
        storeId: storeId ?? this.storeId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        images: images ?? this.images,
        stock: stock ?? this.stock,
        status: status ?? this.status,
        soldCount: soldCount ?? this.soldCount,
        isDeleted: isDeleted ?? this.isDeleted,
        likeId: likeId ?? this.likeId,
        imageUrl: imageUrl ?? this.imageUrl,
        storeName: storeName ?? this.storeName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// lib/core/models/menu_item.dart