import 'package:dio/dio.dart';
import '../models/store_model.dart';

class StoreRepository {
  final Dio dio;

  StoreRepository(this.dio);

  Future<List<StoreModel>> getMyStores() async {
    final res = await dio.get('/me/stores');
    final raw = res.data;
    final list = raw is List ? raw : (raw as Map)['stores'] as List? ?? [];
    return list.map((e) => StoreModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StoreModel> getStore(String storeId) async {
    final res = await dio.get('/me/stores/$storeId');
    final raw = res.data;
    return StoreModel.fromJson(raw is Map<String, dynamic> ? raw : raw['store']);
  }

  Future<StoreModel> createStore(Map<String, dynamic> data) async {
    final res = await dio.post('/me/stores', data: data);
    final raw = res.data;
    return StoreModel.fromJson(raw is Map<String, dynamic> ? raw : raw['store']);
  }

  Future<StoreModel> updateStore(String storeId, Map<String, dynamic> data) async {
    final res = await dio.patch('/me/stores/$storeId', data: data);
    final raw = res.data;
    return StoreModel.fromJson(raw is Map<String, dynamic> ? raw : raw['store']);
  }

  Future<StoreModel> updateAvatar(String storeId, String avatarUrl) async {
    final res = await dio.post('/me/stores/$storeId/avatar', data: {'avatarUrl': avatarUrl});
    final raw = res.data;
    return StoreModel.fromJson(raw is Map<String, dynamic> ? raw : raw['store']);
  }

  Future<StoreModel> updateCover(String storeId, String coverUrl) async {
    final res = await dio.post('/me/stores/$storeId/cover', data: {'coverUrl': coverUrl});
    final raw = res.data;
    return StoreModel.fromJson(raw is Map<String, dynamic> ? raw : raw['store']);
  }
}