// lib/core/providers/favorites_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../models/store.dart';
import '../network/dio_client.dart';
import '../network/api_endpoints.dart';

final favItemsProvider = FutureProvider.autoDispose<List<MenuItem>>((ref) async {
  debugPrint('[FAV-DEBUG] favItemsProvider: fetching...');
  final res = await DioClient.instance.get(ApiEndpoints.favoriteItems);
  final list = res.data is Map ? (res.data['items'] ?? res.data['data'] ?? []) : res.data;
  final result = (list as List)
      .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
      .toList();
  debugPrint('[FAV-DEBUG] favItemsProvider: got ${result.length} items');
  return result;
});

final favStoresProvider = FutureProvider.autoDispose<List<Store>>((ref) async {
  debugPrint('[FAV-DEBUG] favStoresProvider: fetching...');
  final res = await DioClient.instance.get(ApiEndpoints.favoriteStores);
  final list = res.data is Map ? (res.data['stores'] ?? res.data['data'] ?? []) : res.data;
  final result = (list as List)
      .map((e) => Store.fromJson(e as Map<String, dynamic>))
      .toList();
  debugPrint('[FAV-DEBUG] favStoresProvider: got ${result.length} stores');
  return result;
});
