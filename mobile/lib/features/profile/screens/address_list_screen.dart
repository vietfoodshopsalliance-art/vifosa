// vifosa/mobile/lib/features/profile/screens/address_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_providers.dart';
import '../models/address_model.dart';
import 'add_address_screen.dart';

class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    // Force fresh fetch for the current user every time this screen opens,
    // preventing stale data from a previously logged-in user.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final addrAsync = ref.watch(addressNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Địa chỉ của tôi')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAddressScreen()),
        ).then((_) => ref.read(addressNotifierProvider.notifier).load()),
        child: const Icon(Icons.add),
      ),
      body: addrAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (addresses) => addresses.isEmpty
            ? const Center(child: Text('Chưa có địa chỉ nào'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) => _AddressTile(
                  address: addresses[i],
                  onSetDefault: () =>
                      ref.read(addressNotifierProvider.notifier).setDefault(addresses[i].id),
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddAddressScreen(initialAddress: addresses[i]),
                    ),
                  ).then((_) => ref.read(addressNotifierProvider.notifier).load()),
                  onDelete: () => _confirmDelete(context, addresses[i].id),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá địa chỉ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(addressNotifierProvider.notifier).delete(id);
  }
}

class _AddressTile extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.address,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.location_on,
          color: address.isDefault ? Colors.orange : Colors.grey),
      title: Row(
        children: [
          Text(address.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (address.isDefault) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Mặc định', style: TextStyle(fontSize: 10, color: Colors.orange)),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${address.receiverName} · ${address.receiverPhone}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          if (!address.isDefault)
            const PopupMenuItem(value: 'default', child: Text('Đặt mặc định')),
          const PopupMenuItem(value: 'edit', child: Text('Sửa')),
          const PopupMenuItem(value: 'delete', child: Text('Xoá')),
        ],
        onSelected: (v) {
          if (v == 'default') onSetDefault();
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
      ),
    );
  }
}