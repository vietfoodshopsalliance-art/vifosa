import 'package:dio/dio.dart';
import '../models/store_model.dart';

class StoreRepository {
  final Dio dio;

  StoreRepository(this.dio);

  Future<List<StoreModel>> getMyStores() async {
    final res = await dio.get('/me/stores');
    return (res.data['stores'] as List).map((e) => StoreModel.fromJson(e)).toList();
  }

  Future<StoreModel> getStore(String storeId) async {
    final res = await dio.get('/stores/$storeId');
    return StoreModel.fromJson(res.data['store']);
  }

  Future<StoreModel> createStore(Map<String, dynamic> data) async {
    final res = await dio.post('/stores', data: data);
    return StoreModel.fromJson(res.data['store']);
  }

  Future<StoreModel> updateStore(String storeId, Map<String, dynamic> data) async {
    final res = await dio.patch('/stores/$storeId', data: data);
    return StoreModel.fromJson(res.data['store']);
  }

  Future<StoreModel> updateAvatar(String storeId, String avatarUrl) async {
    final res = await dio.post('/stores/$storeId/avatar', data: {'avatarUrl': avatarUrl});
    return StoreModel.fromJson(res.data['store']);
  }

  Future<StoreModel> updateCover(String storeId, String coverUrl) async {
    final res = await dio.post('/stores/$storeId/cover', data: {'coverUrl': coverUrl});
    return StoreModel.fromJson(res.data['store']);
  }
}