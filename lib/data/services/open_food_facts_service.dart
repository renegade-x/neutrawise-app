import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/co2_engine/emission_factors.dart';

final openFoodFactsProvider = Provider((ref) => OpenFoodFactsService());

class OpenFoodFactsProduct {
  final String id;
  final String name;
  final String? brand;
  final String? ecoScore;
  final double? co2Total;
  final String? fallbackCategory;

  OpenFoodFactsProduct({
    required this.id,
    required this.name,
    this.brand,
    this.ecoScore,
    this.co2Total,
    this.fallbackCategory,
  });

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    // Attempt to extract CO2 data (agribalyse_co2_total) or ecoscore data
    double? co2;
    if (json['ecoscore_data'] != null &&
        json['ecoscore_data']['agribalyse'] != null) {
      co2 = (json['ecoscore_data']['agribalyse']['co2_total'] as num?)
          ?.toDouble();
    }

    return OpenFoodFactsProduct(
      id: json['id'] ?? json['code'] ?? '',
      name: json['product_name'] ?? 'Unknown Product',
      brand: json['brands'],
      ecoScore: json['ecoscore_grade'],
      co2Total: co2,
      fallbackCategory: EmissionFactors.mapOFFCategoryToFactorKey(
        json['categories'] ?? '',
      ),
    );
  }
}

class OpenFoodFactsService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/cgi/search.pl';

  Future<List<OpenFoodFactsProduct>> searchFood(String query) async {
    if (query.isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_baseUrl?search_terms=$query&search_simple=1&action=process&json=1&page_size=10',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'NeutraWiseApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['products'] as List;
        return products.map((p) => OpenFoodFactsProduct.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      print('OFF API Error: $e');
      return [];
    }
  }
}
