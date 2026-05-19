// vifosa/mobile/lib/features/profile/providers/profile_providers.dart

/* import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/profile_repository.dart';
import '../models/address_model.dart';
import '../../../core/providers/dio_provider.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.read(dioProvider)));

final addressesProvider = FutureProvider<List<AddressModel>>((ref) async {
  return ref.read(profileRepositoryProvider).getAddresses();
});

class AddressNotifier extends StateNotifier<AsyncValue<List<AddressModel>>> {
  final ProfileRepository _repo;

  AddressNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAddresses());
  }

  Future<void> add(Map<String, dynamic> data) async {
    await _repo.addAddress(data);
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _repo.updateAddress(id, data);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.deleteAddress(id);
    await load();
  }

  Future<void> setDefault(String id) async {
    await _repo.setDefaultAddress(id);
    await load();
  }
}

final addressNotifierProvider =
    StateNotifierProvider<AddressNotifier, AsyncValue<List<AddressModel>>>((ref) {
  return AddressNotifier(ref.read(profileRepositoryProvider));
});
*/
// lib/features/profile/providers/profile_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(DioClient().dio);
});