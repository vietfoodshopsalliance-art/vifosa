// lib/features/store_dashboard/reviews/reply_dialog.dart

import 'package:flutter/material.dart';

class ReplyDialog extends StatefulWidget {
  final String? initialReply;
  final Future<void> Function(String reply) onSave;

  const ReplyDialog({super.key, this.initialReply, required this.onSave});

  @override
  State<ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<ReplyDialog> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  bool get _isEdit => widget.initialReply != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialReply ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng nhập phản hồi')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.onSave(text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Sửa phản hồi' : 'Phản hồi đánh giá'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Nhập phản hồi của quán...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Gửi'),
        ),
      ],
    );
  }
}