import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/store_repository.dart';
import '../models/store_model.dart';
import '../../../core/providers/dio_provider.dart';

final storeRepositoryProvider = Provider((ref) => StoreRepository(ref.read(dioProvider)));

final myStoresProvider = FutureProvider<List<StoreModel>>((ref) async {
  return ref.read(storeRepositoryProvider).getMyStores();
});

final storeDetailProvider = FutureProvider.family<StoreModel, String>((ref, storeId) async {
  return ref.read(storeRepositoryProvider).getStore(storeId);
});

class StoreNotifier extends StateNotifier<AsyncValue<List<StoreModel>>> {
  final StoreRepository _repo;

  StoreNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getMyStores());
  }

  Future<StoreModel> createStore(Map<String, dynamic> data) async {
    final store = await _repo.createStore(data);
    await load();
    return store;
  }

  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    await _repo.updateStore(storeId, data);
    await load();
  }
}

final storeNotifierProvider =
    StateNotifierProvider<StoreNotifier, AsyncValue<List<StoreModel>>>((ref) {
  return StoreNotifier(ref.read(storeRepositoryProvider));
});