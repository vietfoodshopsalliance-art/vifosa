// lib/features/home/models/food_item_card.dart

class FoodItemCard {
  final String id;
  final String name;
  final String? description;
  final int price;
  final String? image;
  final int soldCount;
  final double? distanceKm;
  final String storeId;
  final double avgRating;
  final int totalReviews;

  const FoodItemCard({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.image,
    required this.soldCount,
    this.distanceKm,
    required this.storeId,
    required this.avgRating,
    required this.totalReviews,
  });

  factory FoodItemCard.fromJson(Map<String, dynamic> j) => FoodItemCard(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        price: (j['price'] as num).toInt(),
        image: j['image'] as String?,
        soldCount: (j['soldCount'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        storeId: j['storeId'] as String,
        avgRating: (j['avgRating'] as num?)?.toDouble() ?? 0.0,
        totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
      );

  // Dòng đầu tiên sau "Đặc trưng:" trong description
  String? get feature {
    if (description == null || description!.isEmpty) return null;
    for (final line in description!.split('\n')) {
      final l = line.trim();
      if (l.startsWith('Đặc trưng:')) {
        final val = l.substring('Đặc trưng:'.length).trim();
        return val.isEmpty ? null : val;
      }
    }
    return null;
  }

  // Dòng sau "Giá cũ:" → parse thành int (VND)
  int? get oldPrice {
    if (description == null || description!.isEmpty) return null;
    for (final line in description!.split('\n')) {
      final l = line.trim();
      if (l.startsWith('Giá cũ:')) {
        final raw = l.substring('Giá cũ:'.length).trim();
        final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
        final val = int.tryParse(digits);
        return (val != null && val > 0) ? val : null;
      }
    }
    return null;
  }
}

List<FoodItemCard> parseFoodItems(dynamic raw) =>
    (raw as List<dynamic>? ?? [])
        .map((e) => FoodItemCard.fromJson(e as Map<String, dynamic>))
        .toList();
