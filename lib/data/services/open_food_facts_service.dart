import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/domain/co2_engine/emission_factors.dart';

final openFoodFactsProvider = Provider(
  (ref) => FoodService(Supabase.instance.client),
);
final foodServiceProvider = openFoodFactsProvider;

class OpenFoodFactsProduct {
  final String id;
  final String name;
  final String? brand;
  final String? ecoScore;
  final double? co2Total;
  final String? fallbackCategory;
  final String source;

  OpenFoodFactsProduct({
    required this.id,
    required this.name,
    this.brand,
    this.ecoScore,
    this.co2Total,
    this.fallbackCategory,
    this.source = 'Open Food Facts',
  });

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    double? co2;
    if (json['ecoscore_data'] != null &&
        json['ecoscore_data']['agribalyse'] != null) {
      co2 = (json['ecoscore_data']['agribalyse']['co2_total'] as num?)
          ?.toDouble();
    } else if (json['co2_total'] != null) {
      co2 = (json['co2_total'] as num?)?.toDouble();
    }

    return OpenFoodFactsProduct(
      id: (json['id'] ?? json['code'] ?? '').toString(),
      name: json['product_name'] ?? json['name'] ?? 'Unknown Product',
      brand: json['brands'] ?? json['brand'] ?? 'Pakistani Dish',
      ecoScore: json['ecoscore_grade'] ?? json['eco_score'] ?? 'c',
      co2Total: co2,
      fallbackCategory:
          json['category'] ??
          json['fallback_category'] ??
          EmissionFactors.mapOFFCategoryToFactorKey(json['categories'] ?? ''),
      source: json['source'] ?? 'Open Food Facts',
    );
  }
}

class FoodService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/cgi/search.pl';

  final SupabaseClient? _supabase;

  static const List<Map<String, dynamic>> _defaultPakistaniDishes = [
    {
      'id': 'pk_1',
      'name': 'Chicken Biryani',
      'brand': 'Traditional Pakistani Dish',
      'category': 'poultry',
      'co2_total': 1.8,
      'eco_score': 'c',
    },
    {
      'id': 'pk_2',
      'name': 'Beef Biryani',
      'brand': 'Traditional Pakistani Dish',
      'category': 'beef',
      'co2_total': 4.5,
      'eco_score': 'e',
    },
    {
      'id': 'pk_3',
      'name': 'Mutton Karahi',
      'brand': 'Traditional Pakistani Dish',
      'category': 'lamb',
      'co2_total': 5.2,
      'eco_score': 'e',
    },
    {
      'id': 'pk_4',
      'name': 'Chicken Karahi',
      'brand': 'Traditional Pakistani Dish',
      'category': 'poultry',
      'co2_total': 1.7,
      'eco_score': 'c',
    },
    {
      'id': 'pk_5',
      'name': 'Daal Chawal (Lentil Rice)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'legumes',
      'co2_total': 0.6,
      'eco_score': 'a',
    },
    {
      'id': 'pk_6',
      'name': 'Aloo Palak (Spinach Potato)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'vegetables',
      'co2_total': 0.4,
      'eco_score': 'a',
    },
    {
      'id': 'pk_7',
      'name': 'Nihari (Beef Stew)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'beef',
      'co2_total': 4.8,
      'eco_score': 'e',
    },
    {
      'id': 'pk_8',
      'name': 'Haleem (Lentil Meat Stew)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'beef',
      'co2_total': 3.2,
      'eco_score': 'd',
    },
    {
      'id': 'pk_9',
      'name': 'Chapli Kabab',
      'brand': 'Traditional Pakistani Dish',
      'category': 'beef',
      'co2_total': 4.2,
      'eco_score': 'e',
    },
    {
      'id': 'pk_10',
      'name': 'Chicken Seekh Kabab',
      'brand': 'Traditional Pakistani Dish',
      'category': 'poultry',
      'co2_total': 1.6,
      'eco_score': 'c',
    },
    {
      'id': 'pk_11',
      'name': 'Samosa (Potato/Pea)',
      'brand': 'Traditional Pakistani Snack',
      'category': 'vegetables',
      'co2_total': 0.5,
      'eco_score': 'b',
    },
    {
      'id': 'pk_12',
      'name': 'Aloo Paratha',
      'brand': 'Traditional Pakistani Flatbread',
      'category': 'grains',
      'co2_total': 0.7,
      'eco_score': 'b',
    },
    {
      'id': 'pk_13',
      'name': 'Tandoori Naan',
      'brand': 'Traditional Pakistani Bread',
      'category': 'grains',
      'co2_total': 0.4,
      'eco_score': 'a',
    },
    {
      'id': 'pk_14',
      'name': 'Halwa Puri Chana',
      'brand': 'Traditional Pakistani Breakfast',
      'category': 'legumes',
      'co2_total': 0.9,
      'eco_score': 'b',
    },
    {
      'id': 'pk_15',
      'name': 'Kheer (Rice Pudding)',
      'brand': 'Traditional Pakistani Dessert',
      'category': 'dairy',
      'co2_total': 1.1,
      'eco_score': 'c',
    },
    {
      'id': 'pk_16',
      'name': 'Fish Fry (Lahori)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'fish',
      'co2_total': 1.9,
      'eco_score': 'c',
    },
    {
      'id': 'pk_17',
      'name': 'Mix Sabzi (Assorted Veggies)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'vegetables',
      'co2_total': 0.3,
      'eco_score': 'a',
    },
    {
      'id': 'pk_18',
      'name': 'Chana Masala (Chickpeas)',
      'brand': 'Traditional Pakistani Dish',
      'category': 'legumes',
      'co2_total': 0.5,
      'eco_score': 'a',
    },
    {
      'id': 'pk_19',
      'name': 'Siri Paye',
      'brand': 'Traditional Pakistani Dish',
      'category': 'beef',
      'co2_total': 4.6,
      'eco_score': 'e',
    },
    {
      'id': 'pk_20',
      'name': 'Chicken Pulao',
      'brand': 'Traditional Pakistani Dish',
      'category': 'poultry',
      'co2_total': 1.5,
      'eco_score': 'c',
    },
  ];

  FoodService([this._supabase]);

  Future<List<OpenFoodFactsProduct>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();
    final List<OpenFoodFactsProduct> results = [];

    // Step 1: Query Supabase pakistani_foods primary DB
    if (_supabase != null) {
      try {
        final List<dynamic> pkResponse = await _supabase
            .from('pakistani_foods')
            .select()
            .ilike('name', '%$q%')
            .limit(10);

        if (pkResponse.isNotEmpty) {
          for (final item in pkResponse) {
            final m = Map<String, dynamic>.from(item as Map);
            results.add(
              OpenFoodFactsProduct(
                id: (m['id'] ?? '').toString(),
                name: m['name'] as String? ?? '',
                brand: m['brand'] as String? ?? 'Pakistani Dish',
                ecoScore: m['eco_score'] as String? ?? 'c',
                co2Total: (m['co2_total'] as num?)?.toDouble() ?? 1.5,
                fallbackCategory: m['category'] as String? ?? 'poultry',
                source: 'Pakistani Dish DB',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Supabase pakistani_foods query error: $e');
      }
    }

    // Step 2: Fallback to local Pakistani Dishes embedded catalog if Supabase empty / offline
    if (results.isEmpty) {
      final matchedLocal = _defaultPakistaniDishes.where((item) {
        final name = (item['name'] as String).toLowerCase();
        return name.contains(q);
      }).toList();

      for (final m in matchedLocal) {
        results.add(
          OpenFoodFactsProduct(
            id: m['id'] as String,
            name: m['name'] as String,
            brand: m['brand'] as String,
            ecoScore: m['eco_score'] as String,
            co2Total: (m['co2_total'] as num).toDouble(),
            fallbackCategory: m['category'] as String,
            source: 'Pakistani Dish DB',
          ),
        );
      }
    }

    // Step 3: Fetch Open Food Facts as fallback or supplementary products
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
        for (var p in products) {
          final prod = OpenFoodFactsProduct.fromJson(p);
          if (!results.any(
            (r) => r.name.toLowerCase() == prod.name.toLowerCase(),
          )) {
            results.add(prod);
          }
        }
      }
    } catch (e) {
      debugPrint('OFF API Error: $e');
    }

    return results;
  }
}
