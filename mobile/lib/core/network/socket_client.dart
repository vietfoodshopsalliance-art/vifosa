// lib/core/network/socket_client.dart
// Real-time Socket.IO client — order tracking & store dashboard

import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

class SocketClient {
  static final SocketClient _instance = SocketClient._internal();
  factory SocketClient() => _instance;
  SocketClient._internal();

  io.Socket? _socket;

  // ─── Internal ─────────────────────────────────────────────────────────────

  io.Socket _getOrCreate() {
    _socket ??= io.io(
      Env.apiBaseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionAttempts': 10,
        'timeout': 10000,
      },
    );
    return _socket!;
  }

  // ─── Room management ──────────────────────────────────────────────────────

  /// Join room cho một order cụ thể. Backend: socket.on('join:order', ...)
  void joinOrderRoom(String orderId) =>
      _getOrCreate().emit('join:order', orderId);

  /// Leave room order. Backend: socket.on('leave:order', ...)
  void leaveOrderRoom(String orderId) =>
      _socket?.emit('leave:order', orderId);

  /// Join room store để nhận new_order / order:updated.
  /// Backend: socket.on('join:store', ...)
  void joinStore(String storeId) =>
      _getOrCreate().emit('join:store', storeId);

  /// Backend chưa có leave:store handler — emit để forward-compatible.
  void leaveStore(String storeId) =>
      _socket?.emit('leave:store', storeId);

  // ─── Event listeners ──────────────────────────────────────────────────────

  /// Đăng ký listener cho một event. Ghi đè listener cũ nếu event đã được đăng ký.
  void on(String event, void Function(dynamic data) callback) {
    final s = _getOrCreate();
    s.off(event);
    s.on(event, callback);
  }

  /// Huỷ listener cho một event.
  void off(String event) => _socket?.off(event);

  // ─── Convenience methods ──────────────────────────────────────────────────

  /// Lắng nghe event order_status_changed từ room order:${orderId}.
  /// Payload: { orderId: String, status: String }
  void onOrderStatusChanged(
      void Function(Map<String, dynamic> data) callback) {
    on('order_status_changed',
        (data) => callback(Map<String, dynamic>.from(data as Map)));
  }

  /// Lắng nghe event payment_status_changed từ room order:${orderId}.
  /// Payload: { orderId: String, paymentStatus: String }
  void onPaymentStatusChanged(
      void Function(Map<String, dynamic> data) callback) {
    on('payment_status_changed',
        (data) => callback(Map<String, dynamic>.from(data as Map)));
  }
}
