// lib/core/widgets/report_dialog.dart

import 'package:flutter/material.dart';
import '../network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;

  const _ReportSheet({required this.targetType, required this.targetId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    'Nội dung phản cảm / tục tĩu',
    'Quảng cáo spam',
    'Thông tin sai lệch / gian lận',
    'Quấy rối / bắt nạt',
    'Khác',
  ];

  String? _selectedReason;
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);
    try {
      await DioClient().dio.post(
        ApiEndpoints.reports,
        data: {
          'targetType': widget.targetType,
          'targetId': widget.targetId,
          'reason': _selectedReason,
          if (_selectedReason == 'Khác' && _descController.text.isNotEmpty)
            'description': _descController.text.trim(),
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đã gửi báo cáo. Admin sẽ xem xét.')),
        );
      }
    } catch (_) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Báo cáo vi phạm',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ..._reasons.map(
              (r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _selectedReason,
                onChanged: (v) => setState(() => _selectedReason = v),
                dense: true,
              ),
            ),
            if (_selectedReason == 'Khác')
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    hintText: 'Mô tả thêm...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_selectedReason == null || _isSubmitting)
                          ? null
                          : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi báo cáo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
