// lib/core/providers/favorites_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../models/store.dart';
import '../network/dio_client.dart';
import '../network/api_endpoints.dart';

final favItemsProvider = FutureProvider.autoDispose<List<MenuItem>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.favoriteItems);
  final list = res.data is Map ? (res.data['items'] ?? res.data['data'] ?? []) : res.data;
  return (list as List)
      .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final favStoresProvider = FutureProvider.autoDispose<List<Store>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.favoriteStores);
  final list = res.data is Map ? (res.data['stores'] ?? res.data['data'] ?? []) : res.data;
  return (list as List)
      .map((e) => Store.fromJson(e as Map<String, dynamic>))
      .toList();
});
