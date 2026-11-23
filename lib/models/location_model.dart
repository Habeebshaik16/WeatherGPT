
class LocationModel {
  final String name;
  final String country;
  final String? admin1;
  final String? admin2;
  final double latitude;
  final double longitude;

  const LocationModel({
    required this.name,
    required this.country,
    this.admin1,
    this.admin2,
    required this.latitude,
    required this.longitude,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      name: json['name']?.toString() ?? 'Unknown',
      country: json['country']?.toString() ?? '',
      admin1: _cleanValue(json['admin1']),
      admin2: _cleanValue(json['admin2']),
      latitude: _parseCoordinate(json['latitude']),
      longitude: _parseCoordinate(json['longitude']),
    );
  }

  static String? _cleanValue(dynamic value) {
    final result = value?.toString().trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }

  static double _parseCoordinate(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value?.toString() ?? '');

    if (parsed == null) {
      throw FormatException('Invalid location coordinates.');
    }

    return parsed;
  }

  String get displayName {
    final parts = <String>[name];

    if (admin1 != null &&
        admin1!.toLowerCase() != name.toLowerCase()) {
      parts.add(admin1!);
    }

    if (country.isNotEmpty) {
      parts.add(country);
    }

    return parts.join(', ');
  }

  String get details {
    final parts = <String>[];

    if (admin2 != null) {
      parts.add(admin2!);
    }

    if (admin1 != null) {
      parts.add(admin1!);
    }

    if (country.isNotEmpty) {
      parts.add(country);
    }

    return parts.toSet().join(', ');
  }
}
