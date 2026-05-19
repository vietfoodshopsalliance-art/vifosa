// vifosa/mobile/lib/shared/utils/cloudinary_upload.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CloudinaryUpload {
  static const _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dvubr3dwm',
  );
  static const _uploadPreset = 'ml_default';

  static Future<String> uploadImage({
    required String filePath,
    required String folder,
    String transformation = '',
  }) async {
    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'upload_preset': _uploadPreset,
      'folder': folder,
    });

    late final Response res;
    try {
      res = await dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        data: formData,
        options: Options(validateStatus: (_) => true),
      );
    } catch (e) {
      debugPrint('Cloudinary raw error: $e');
      rethrow;
    }
    debugPrint('Cloudinary status: ${res.statusCode}');
    debugPrint('Cloudinary body: ${res.data}');
    if (res.statusCode != 200) {
      throw Exception('Cloudinary ${res.statusCode}: ${res.data}');
    }
    final publicId = res.data['public_id'] as String;
    final transform = transformation.isNotEmpty ? '$transformation/' : '';
    return 'https://res.cloudinary.com/$_cloudName/image/upload/$transform$publicId';
  }
}

// vifosa/mobile/lib/shared/utils/cloudinary_upload.dart