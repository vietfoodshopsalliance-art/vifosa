// lib/features/store_dashboard/orders/widgets/reject_dialog.dart

import 'package:flutter/material.dart';

class RejectDialog extends StatefulWidget {
  final Future<void> Function(String reason) onConfirm;

  const RejectDialog({super.key, required this.onConfirm});

  @override
  State<RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<RejectDialog> {
  static const _presetReasons = [
    'Hết nguyên liệu',
    'Quán đang bận',
    'Địa chỉ quá xa',
    'Khác',
  ];

  String _selected = 'Hết nguyên liệu';
  final _customCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final reason =
        _selected == 'Khác' ? _customCtrl.text.trim() : _selected;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng nhập lý do')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.onConfirm(reason);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Từ chối đơn hàng'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._presetReasons.map((reason) => RadioListTile<String>(
                  value: reason,
                  groupValue: _selected,
                  title: Text(reason),
                  onChanged: (v) => setState(() => _selected = v!),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
            if (_selected == 'Khác') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customCtrl,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Nhập lý do từ chối...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _loading ? null : _confirm,
          style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600),
          child: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Xác nhận từ chối'),
        ),
      ],
    );
  }
}