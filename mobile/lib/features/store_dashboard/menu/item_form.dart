// lib/features/store_dashboard/menu/item_form.dart

import 'package:flutter/material.dart';
import '../models/store_menu_item.dart';

class ItemFormScreen extends StatelessWidget {
  final String storeId;
  final String categoryId;
  final StoreMenuItem? item;

  const ItemFormScreen({
    super.key,
    required this.storeId,
    required this.categoryId,
    this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item != null ? 'Sửa món' : 'Thêm món'),
      ),
      body: const Center(child: Text('Form chỉnh sửa món ăn')),
    );
  }
}
