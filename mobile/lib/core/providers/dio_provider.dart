// lib/core/providers/dio_provider.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
export '../network/dio_client.dart';

import '../network/dio_client.dart';

/// Provider trả về Dio singleton — dùng cho các Repository cần inject Dio.
final dioProvider = Provider<Dio>((_) => DioClient.instance);