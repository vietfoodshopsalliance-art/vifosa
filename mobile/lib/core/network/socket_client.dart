// lib/core/network/socket_client.dart

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';

class SocketClient {
  static final SocketClient _instance = SocketClient._internal();
  factory SocketClient() => _instance;
  SocketClient._internal();

  io.Socket? _socket;

  Future<void> connect({required String accessToken}) async {
    _socket?.disconnect();
    _socket = io.io(
      apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) => debugPrint('[Socket] connected'));
    _socket!.onDisconnect((_) => debugPrint('[Socket] disconnected'));
    _socket!.onError((e) => debugPrint('[Socket] error: $e'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  io.Socket? get socket => _socket;
}
