// lib/core/widgets/order_code_text.dart

import 'package:flutter/material.dart';

/// Hiển thị mã đơn: phần đầu (VD: "AB251107-") màu mờ, 3 số cuối in đậm lớn.
/// Ví dụ: code = "AB251107-456"
class OrderCodeText extends StatelessWidget {
  final String code;
  final double suffixFontSize;

  const OrderCodeText({
    super.key,
    required this.code,
    this.suffixFontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final dashIndex = code.lastIndexOf('-');
    final prefix = dashIndex >= 0 ? code.substring(0, dashIndex + 1) : code;
    final suffix = dashIndex >= 0 ? code.substring(dashIndex + 1) : '';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(
              color: Colors.black45,
              fontSize: suffixFontSize - 4,
            ),
          ),
          TextSpan(
            text: suffix,
            style: TextStyle(
              color: Colors.black87,
              fontSize: suffixFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}