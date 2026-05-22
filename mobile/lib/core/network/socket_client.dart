// lib/core/network/socket_client.dart
// Stub — WebSocket/Socket.IO client for order tracking

class SocketClient {
  static final SocketClient _instance = SocketClient._internal();
  factory SocketClient() => _instance;
  SocketClient._internal();

  final Map<String, Function> _handlers = {};

  void joinOrderRoom(String orderId) {}
  void leaveOrderRoom(String orderId) {}
  void joinStore(String storeId) {}
  void leaveStore(String storeId) {}
  void off(String event) => _handlers.remove(event);
  void on(String event, void Function(dynamic data) callback) {
    _handlers[event] = callback;
  }

  void onOrderStatusChanged(void Function(Map<String, dynamic> data) callback) {
    _handlers['order_status_changed'] = callback;
  }

  void onPaymentStatusChanged(void Function(Map<String, dynamic> data) callback) {
    _handlers['payment_status_changed'] = callback;
  }
}
