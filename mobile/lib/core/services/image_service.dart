// lib/core/services/image_service.dart

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../network/api_endpoints.dart';
import '../../shared/utils/cloudinary_upload.dart';

class UploadedImage {
  final String url;
  final String publicId;

  const UploadedImage({required this.url, required this.publicId});

  factory UploadedImage.fromJson(Map<String, dynamic> json) => UploadedImage(
        url: json['url'] as String,
        publicId: json['publicId'] as String,
      );
}

enum ImageUploadContext { avatar, storeCover, storeAvatar, menuItem, post, review, refundProof, foodPhoto, receipt }

extension ImageUploadContextX on ImageUploadContext {
  String get value => switch (this) {
        ImageUploadContext.avatar       => 'avatar',
        ImageUploadContext.storeCover   => 'store_cover',
        ImageUploadContext.storeAvatar  => 'store_avatar',
        ImageUploadContext.menuItem     => 'menu_item',
        ImageUploadContext.post         => 'post',
        ImageUploadContext.review       => 'review',
        ImageUploadContext.refundProof  => 'refund_proof',
        ImageUploadContext.foodPhoto    => 'food_photos',
        ImageUploadContext.receipt      => 'receipts',
      };
}

class ImageService {
  ImageService._();
  static final instance = ImageService._();

  final _picker = ImagePicker();
  final _dio = DioClient.instance;

  // ── Chọn ảnh ───────────────────────────────────────────────────────────────

  Future<XFile?> pickSingle({ImageSource source = ImageSource.gallery}) =>
      _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );

  Future<List<XFile>> pickMultiple({int limit = 5}) async {
    final files = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (files.length > limit) return files.sublist(0, limit);
    return files;
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<UploadedImage> uploadFile(
    File file, {
    required ImageUploadContext context,
    void Function(int sent, int total)? onProgress,
  }) async {
    final url = await CloudinaryUpload.uploadImage(
      filePath: file.path,
      folder: context.value,
    );
    final publicId = url.split('/upload/').last;
    return UploadedImage(url: url, publicId: publicId);
  }

  Future<UploadedImage> uploadXFile(
    XFile xFile, {
    required ImageUploadContext context,
    void Function(int sent, int total)? onProgress,
  }) =>
      uploadFile(File(xFile.path), context: context, onProgress: onProgress);

  Future<List<UploadedImage>> uploadMultiple(
    List<XFile> files, {
    required ImageUploadContext context,
  }) async {
    final futures = files.map((f) => uploadXFile(f, context: context));
    return Future.wait(futures);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteImage(String publicId) async {
    await _dio.delete(
      ApiEndpoints.uploads,
      data: {'publicId': publicId},
    );
  }

}

final imageServiceProvider = Provider<ImageService>((_) => ImageService.instance);

// lib/core/services/image_service.dart