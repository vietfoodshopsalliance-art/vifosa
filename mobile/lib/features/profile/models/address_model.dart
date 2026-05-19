// vifosa/mobile/lib/features/profile/models/address_model.dart

class AddressModel {
  final String id;
  final String label;
  final String text;
  final double lat;
  final double lng;
  final String receiverName;
  final String receiverPhone;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.label,
    required this.text,
    required this.lat,
    required this.lng,
    required this.receiverName,
    required this.receiverPhone,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final coords = json['address']?['location']?['coordinates'] ?? [0.0, 0.0];
    return AddressModel(
      id: json['_id'] ?? '',
      label: json['label'] ?? '',
      text: json['address']?['text'] ?? '',
      lat: (coords[1] as num).toDouble(),
      lng: (coords[0] as num).toDouble(),
      receiverName: json['receiver']?['name'] ?? '',
      receiverPhone: json['receiver']?['phone'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }
}