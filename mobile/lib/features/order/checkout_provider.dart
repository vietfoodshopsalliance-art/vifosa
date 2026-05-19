// lib/features/order/checkout_provider.dart

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum DeliveryMethod { storeDelivery, selfPickup, ownShipper }

enum PaymentMethod { bankTransfer, cod, half, momo, zalopay }

// ─── Address Model ────────────────────────────────────────────────────────────

class DeliveryAddress {
  final String id;
  final String label;
  final String text;
  final double? lat;
  final double? lng;

  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.text,
    this.lat,
    this.lng,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) => DeliveryAddress(
        id: json['_id'] as String,
        label: json['label'] as String? ?? '',
        text: json['text'] as String,
        lat: (json['location']?['lat'] as num?)?.toDouble(),
        lng: (json['location']?['lng'] as num?)?.toDouble(),
      );
}

// ─── ShipFee Config ───────────────────────────────────────────────────────────

class ShipFeeConfig {
  final double a; // base fee
  final double b; // per-km fee
  final double c; // percentage surcharge (0-100)

  const ShipFeeConfig({required this.a, required this.b, required this.c});

  double calculate(double km) {
    final raw = (a + b * km) * (1 + c / 100);
    return (raw / 1000).round() * 1000; // round to nearest 1000
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class CheckoutState {
  final List<DeliveryAddress> savedAddresses;
  final DeliveryAddress? selectedAddress;

  // Guest fields
  final String guestName;
  final String guestPhone;
  final String guestEmail;

  // Other recipient
  final bool otherRecipient;
  final String recipientName;
  final String recipientPhone;

  final DeliveryMethod deliveryMethod;
  final PaymentMethod? paymentMethod;

  final double distanceKm;
  final double shipFee;

  final bool isPreOrder;
  final String preOrderOpenTime;

  final bool isLoading;
  final String? error;

  const CheckoutState({
    this.savedAddresses = const [],
    this.selectedAddress,
    this.guestName = '',
    this.guestPhone = '',
    this.guestEmail = '',
    this.otherRecipient = false,
    this.recipientName = '',
    this.recipientPhone = '',
    this.deliveryMethod = DeliveryMethod.storeDelivery,
    this.paymentMethod,
    this.distanceKm = 0,
    this.shipFee = 0,
    this.isPreOrder = false,
    this.preOrderOpenTime = '',
    this.isLoading = false,
    this.error,
  });

  bool get forceTransfer => otherRecipient || isPreOrder;
  bool get distanceTooFar => distanceKm > 25;
  bool get distanceWarning => distanceKm > 10 && distanceKm <= 25;

  CheckoutState copyWith({
    List<DeliveryAddress>? savedAddresses,
    DeliveryAddress? selectedAddress,
    String? guestName,
    String? guestPhone,
    String? guestEmail,
    bool? otherRecipient,
    String? recipientName,
    String? recipientPhone,
    DeliveryMethod? deliveryMethod,
    PaymentMethod? paymentMethod,
    double? distanceKm,
    double? shipFee,
    bool? isPreOrder,
    String? preOrderOpenTime,
    bool? isLoading,
    String? error,
  }) =>
      CheckoutState(
        savedAddresses: savedAddresses ?? this.savedAddresses,
        selectedAddress: selectedAddress ?? this.selectedAddress,
        guestName: guestName ?? this.guestName,
        guestPhone: guestPhone ?? this.guestPhone,
        guestEmail: guestEmail ?? this.guestEmail,
        otherRecipient: otherRecipient ?? this.otherRecipient,
        recipientName: recipientName ?? this.recipientName,
        recipientPhone: recipientPhone ?? this.recipientPhone,
        deliveryMethod: deliveryMethod ?? this.deliveryMethod,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        distanceKm: distanceKm ?? this.distanceKm,
        shipFee: shipFee ?? this.shipFee,
        isPreOrder: isPreOrder ?? this.isPreOrder,
        preOrderOpenTime: preOrderOpenTime ?? this.preOrderOpenTime,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final Ref _ref;
  ShipFeeConfig? _shipFeeConfig;
  double? _storeLat;
  double? _storeLng;

  CheckoutNotifier(this._ref) : super(const CheckoutState());

  void init({
    required ShipFeeConfig shipFeeConfig,
    required double storeLat,
    required double storeLng,
    required bool isPreOrder,
    String preOrderOpenTime = '',
  }) {
    _shipFeeConfig = shipFeeConfig;
    _storeLat = storeLat;
    _storeLng = storeLng;
    state = state.copyWith(
      isPreOrder: isPreOrder,
      preOrderOpenTime: preOrderOpenTime,
    );
  }

  Future<void> loadSavedAddresses() async {
    try {
      final res = await DioClient.instance.get(ApiEndpoints.meAddresses);
      final list = (res.data as List<dynamic>)
          .map((e) => DeliveryAddress.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(savedAddresses: list);
    } catch (_) {}
  }

  void selectAddress(DeliveryAddress addr) {
    state = state.copyWith(selectedAddress: addr);
    if (addr.lat != null && addr.lng != null) {
      _recalcDistance(addr.lat!, addr.lng!);
    }
  }

  void updateGuestCoords(double lat, double lng) {
    final addr = DeliveryAddress(
      id: 'guest',
      label: 'Địa chỉ của bạn',
      text: state.guestName,
      lat: lat,
      lng: lng,
    );
    state = state.copyWith(selectedAddress: addr);
    _recalcDistance(lat, lng);
  }

  void _recalcDistance(double lat, double lng) {
    if (_storeLat == null || _storeLng == null) return;
    final km = _haversineKm(_storeLat!, _storeLng!, lat, lng);
    final rounded = (km * 10).round() / 10;
    final shipFee = state.deliveryMethod == DeliveryMethod.storeDelivery
        ? (_shipFeeConfig?.calculate(rounded) ?? 0)
        : 0.0;
    state = state.copyWith(distanceKm: rounded, shipFee: shipFee);
  }

  void setDeliveryMethod(DeliveryMethod method) {
    final dist = state.distanceKm;
    final shipFee = method == DeliveryMethod.storeDelivery
        ? (_shipFeeConfig?.calculate(dist) ?? 0)
        : 0.0;
    // Force bank transfer when other recipient or pre-order
    PaymentMethod? pm = state.paymentMethod;
    if (state.forceTransfer) pm = PaymentMethod.bankTransfer;
    // Remove COD if not store delivery
    if (pm == PaymentMethod.cod && method != DeliveryMethod.storeDelivery) {
      pm = null;
    }
    state = state.copyWith(
        deliveryMethod: method, shipFee: shipFee, paymentMethod: pm);
  }

  void setPaymentMethod(PaymentMethod method) {
    if (state.forceTransfer && method != PaymentMethod.bankTransfer) return;
    state = state.copyWith(paymentMethod: method);
  }

  void setOtherRecipient(bool value) {
    state = state.copyWith(otherRecipient: value);
    if (value) state = state.copyWith(paymentMethod: PaymentMethod.bankTransfer);
  }

  void updateField({
    String? guestName,
    String? guestPhone,
    String? guestEmail,
    String? recipientName,
    String? recipientPhone,
  }) {
    state = state.copyWith(
      guestName: guestName,
      guestPhone: guestPhone,
      guestEmail: guestEmail,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
    );
  }

  // ── Haversine ──────────────────────────────────────────────────────────────

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _deg2rad(double d) => d * pi / 180;

  // ── Parse Google Maps link ─────────────────────────────────────────────────

  static Map<String, double>? parseGoogleMapsLink(String url) {
    // @lat,lng
    final atMatch = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
    if (atMatch != null) {
      return {
        'lat': double.parse(atMatch.group(1)!),
        'lng': double.parse(atMatch.group(2)!),
      };
    }
    // ?q=lat,lng
    final qMatch = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
    if (qMatch != null) {
      return {
        'lat': double.parse(qMatch.group(1)!),
        'lng': double.parse(qMatch.group(2)!),
      };
    }
    return null;
  }
}

final checkoutProvider =
    StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(ref),
);
