// vifosa/mobile/lib/features/profile/repositories/profile_repository.dart

import 'package:dio/dio.dart';
import '../models/address_model.dart';

class ProfileRepository {
  final Dio dio;

  ProfileRepository(this.dio);

  Future<Map<String, dynamic>> getMe() async {
    final res = await dio.get('/me');
    return res.data['user'];
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final res = await dio.patch('/me', data: data);
    return res.data['user'];
  }

  Future<Map<String, dynamic>> updateAvatar(String avatarUrl) async {
    final res = await dio.post('/me/avatar', data: {'avatarUrl': avatarUrl});
    return res.data['user'];
  }

  Future<Map<String, dynamic>> getUserByUsername(String username) async {
    final res = await dio.get('/users/$username');
    return res.data['user'];
  }

  Future<List<AddressModel>> getAddresses() async {
    final res = await dio.get('/me/addresses');
    return (res.data['addresses'] as List).map((e) => AddressModel.fromJson(e)).toList();
  }

  Future<AddressModel> addAddress(Map<String, dynamic> data) async {
    final res = await dio.post('/me/addresses', data: data);
    return AddressModel.fromJson(res.data['address']);
  }

  Future<AddressModel> updateAddress(String id, Map<String, dynamic> data) async {
    final res = await dio.patch('/me/addresses/$id', data: data);
    return AddressModel.fromJson(res.data['address']);
  }

  Future<void> deleteAddress(String id) async {
    await dio.delete('/me/addresses/$id');
  }

  Future<void> setDefaultAddress(String id) async {
    await dio.patch('/me/addresses/$id/default');
  }
}