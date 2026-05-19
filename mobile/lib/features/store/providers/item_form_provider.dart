// lib/features/store/providers/item_form_provider.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Model trạng thái form
// ---------------------------------------------------------------------------

class ItemFormState {
  final String name;
  final String description;
  final String price; // raw string từ TextField
  final String? stock; // null = không quản lý kho
  final String status; // 'active' | 'closed' | 'paused'
  final String categoryId;
  final File? mainImage; // ảnh chính mới chọn (null = giữ ảnh cũ)
  final String? existingImageUrl; // URL ảnh cũ từ Cloudinary
  final List<File> extraImages; // tối đa 4 ảnh phụ (1 chính + max 5 tổng)
  final List<String> existingExtraUrls;
  final bool isSubmitting;
  final String? errorMessage;

  const ItemFormState({
    this.name = '',
    this.description = '',
    this.price = '',
    this.stock,
    this.status = 'active',
    this.categoryId = '',
    this.mainImage,
    this.existingImageUrl,
    this.extraImages = const [],
    this.existingExtraUrls = const [],
    this.isSubmitting = false,
    this.errorMessage,
  });

  bool get isManageStock => stock != null;

  // stock null = không quản lý kho (spec: tồn kho null → không trừ khi đặt)
  int? get parsedStock => stock == null ? null : int.tryParse(stock!);

  double? get parsedPrice => double.tryParse(price.replaceAll(',', ''));

  bool get isValid =>
      name.trim().isNotEmpty &&
      parsedPrice != null &&
      parsedPrice! > 0 &&
      categoryId.isNotEmpty;

  ItemFormState copyWith({
    String? name,
    String? description,
    String? price,
    Object? stock = _sentinel, // dùng sentinel để phân biệt null có chủ ý
    String? status,
    String? categoryId,
    File? mainImage,
    Object? existingImageUrl = _sentinel,
    List<File>? extraImages,
    List<String>? existingExtraUrls,
    bool? isSubmitting,
    Object? errorMessage = _sentinel,
  }) {
    return ItemFormState(
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock == _sentinel ? this.stock : stock as String?,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      mainImage: mainImage ?? this.mainImage,
      existingImageUrl: existingImageUrl == _sentinel
          ? this.existingImageUrl
          : existingImageUrl as String?,
      extraImages: extraImages ?? this.extraImages,
      existingExtraUrls: existingExtraUrls ?? this.existingExtraUrls,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ItemFormNotifier extends StateNotifier<ItemFormState> {
  ItemFormNotifier() : super(const ItemFormState());

  // Khởi tạo form khi sửa món đã có
  void loadExisting({
    required String name,
    required String description,
    required double price,
    required int? stock,
    required String status,
    required String categoryId,
    String? imageUrl,
    List<String> extraUrls = const [],
  }) {
    state = ItemFormState(
      name: name,
      description: description,
      price: price.toStringAsFixed(0),
      stock: stock?.toString(), // null = không quản lý kho
      status: status,
      categoryId: categoryId,
      existingImageUrl: imageUrl,
      existingExtraUrls: extraUrls,
    );
  }

  void setName(String v) => state = state.copyWith(name: v, errorMessage: null);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setPrice(String v) => state = state.copyWith(price: v, errorMessage: null);
  void setStatus(String v) => state = state.copyWith(status: v);
  void setCategoryId(String v) =>
      state = state.copyWith(categoryId: v, errorMessage: null);

  // Toggle quản lý kho: bật → stock = '0', tắt → stock = null
  void toggleManageStock(bool enabled) {
    state = state.copyWith(stock: enabled ? '0' : _sentinel);
    if (!enabled) {
      // xóa stock thật sự khi tắt
      state = ItemFormState(
        name: state.name,
        description: state.description,
        price: state.price,
        stock: null,
        status: state.status,
        categoryId: state.categoryId,
        mainImage: state.mainImage,
        existingImageUrl: state.existingImageUrl,
        extraImages: state.extraImages,
        existingExtraUrls: state.existingExtraUrls,
      );
    }
  }

  void setStock(String v) => state = state.copyWith(stock: v);

  void setMainImage(File file) =>
      state = state.copyWith(mainImage: file, errorMessage: null);

  // Thêm ảnh phụ — tối đa 5 ảnh tổng (1 chính + 4 phụ)
  void addExtraImage(File file) {
    final total =
        1 + state.extraImages.length + state.existingExtraUrls.length;
    if (total >= 5) return; // spec: tối đa 5 ảnh
    state = state.copyWith(extraImages: [...state.extraImages, file]);
  }

  void removeExtraImage(int index) {
    final updated = [...state.extraImages]..removeAt(index);
    state = state.copyWith(extraImages: updated);
  }

  void removeExistingExtraUrl(int index) {
    final updated = [...state.existingExtraUrls]..removeAt(index);
    state = state.copyWith(existingExtraUrls: updated);
  }

  void _setSubmitting(bool v) => state = state.copyWith(isSubmitting: v);
  void _setError(String msg) =>
      state = state.copyWith(isSubmitting: false, errorMessage: msg);

  // Validate cục bộ trước khi gửi
  bool validate() {
    if (state.name.trim().isEmpty) {
      _setError('Vui lòng nhập tên món');
      return false;
    }
    if (state.parsedPrice == null || state.parsedPrice! <= 0) {
      _setError('Giá không hợp lệ');
      return false;
    }
    if (state.categoryId.isEmpty) {
      _setError('Vui lòng chọn danh mục');
      return false;
    }
    if (state.isManageStock &&
        (state.parsedStock == null || state.parsedStock! < 0)) {
      _setError('Tồn kho không hợp lệ');
      return false;
    }
    return true;
  }

  // Gọi từ UI sau khi repo trả về lỗi
  void setError(String msg) => _setError(msg);

  void markSubmitting() => _setSubmitting(true);
  void markDone() => _setSubmitting(false);

  void reset() => state = const ItemFormState();
}

// ---------------------------------------------------------------------------
// Provider — autoDispose vì form chỉ sống khi màn hình mở
// ---------------------------------------------------------------------------

final itemFormProvider =
    StateNotifierProvider.autoDispose<ItemFormNotifier, ItemFormState>(
  (ref) => ItemFormNotifier(),
);

// lib/features/store/providers/item_form_provider.dart