// lib/features/store_dashboard/menu/category_form.dart

import 'package:flutter/material.dart';

class CategoryFormDialog extends StatefulWidget {
  final String? initialName;
  final Future<void> Function(String name) onSave;

  const CategoryFormDialog({
    super.key,
    this.initialName,
    required this.onSave,
  });

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName != null ? 'Sửa danh mục' : 'Thêm danh mục'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Tên danh mục',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final name = _ctrl.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _saving = true);
                  await widget.onSave(name);
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
