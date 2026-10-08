import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
  });
  final String name;
  final String region;
  final String country;
  final double latitude;
  final double longitude;
  String get label =>
      {name, region, country}.where((part) => part.isNotEmpty).join(', ');
}

/// Searches named places without reading the device's location.
class PlaceSearchService {
  Future<List<PlaceResult>> search(String query, String language) async {
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
              'name': query.trim(),
              'count': '10',
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Unable to search locations. Please try again.');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return [
        for (final item in data['results'] as List? ?? [])
          if (item['latitude'] is num && item['longitude'] is num)
            PlaceResult(
              name: item['name'] as String? ?? '',
              region: item['admin1'] as String? ?? '',
              country:
                  item['country'] as String? ??
                  item['country_code'] as String? ??
                  '',
              latitude: (item['latitude'] as num).toDouble(),
              longitude: (item['longitude'] as num).toDouble(),
            ),
      ];
    } finally {
      client.close();
    }
  }
}
