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
  final String? nameUrdu;
  final String? brand;
  final String? ecoScore;
  final double? co2Total;
  final double? co2Per100g;
  final double? servingSizeG;
  final String? mealType;
  final String? co2Source;
  final String? fallbackCategory;
  final String source;

  OpenFoodFactsProduct({
    required this.id,
    required this.name,
    this.nameUrdu,
    this.brand,
    this.ecoScore,
    this.co2Total,
    this.co2Per100g,
    this.servingSizeG,
    this.mealType,
    this.co2Source,
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
    } else if (json['co2_per_100g'] != null) {
      co2 = (json['co2_per_100g'] as num?)?.toDouble();
    }

    final rawCat =
        json['category'] ??
        json['fallback_category'] ??
        json['categories'] ??
        '';

    final normalizedCategory = EmissionFactors.normalizeCategory(
      rawCat.toString(),
    );

    final servingSize =
        (json['serving_size_g'] as num?)?.toDouble() ??
        (json['serving_quantity'] as num?)?.toDouble() ??
        250.0;

    return OpenFoodFactsProduct(
      id: (json['id'] ?? json['code'] ?? '').toString(),
      name: json['product_name'] ?? json['name'] ?? 'Unknown Product',
      nameUrdu: json['name_urdu'] as String?,
      brand: json['brands'] ?? json['brand'] ?? 'Traditional Pakistani',
      ecoScore: json['ecoscore_grade'] ?? json['eco_score'] ?? 'b',
      co2Total: co2,
      co2Per100g: (json['co2_per_100g'] as num?)?.toDouble() ?? co2,
      servingSizeG: servingSize,
      mealType: json['meal_type'] as String?,
      co2Source: json['co2_source'] as String?,
      fallbackCategory: normalizedCategory,
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
      'name_urdu': 'چکن بریانی',
      'brand': 'Traditional Pakistani',
      'category': 'poultry_chicken',
      'co2_per_100g': 1.8,
      'serving_size_g': 350.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'c',
    },
    {
      'id': 'pk_2',
      'name': 'Beef Biryani',
      'name_urdu': 'بیف بریانی',
      'brand': 'Traditional Pakistani',
      'category': 'beef',
      'co2_per_100g': 4.5,
      'serving_size_g': 350.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'e',
    },
    {
      'id': 'pk_3',
      'name': 'Mutton Karahi',
      'name_urdu': 'مٹن کڑاہی',
      'brand': 'Traditional Pakistani',
      'category': 'lamb_mutton',
      'co2_per_100g': 5.2,
      'serving_size_g': 300.0,
      'meal_type': 'Dinner',
      'eco_score': 'e',
    },
    {
      'id': 'pk_4',
      'name': 'Chicken Karahi',
      'name_urdu': 'چکن کڑاہی',
      'brand': 'Traditional Pakistani',
      'category': 'poultry_chicken',
      'co2_per_100g': 1.7,
      'serving_size_g': 300.0,
      'meal_type': 'Dinner',
      'eco_score': 'c',
    },
    {
      'id': 'pk_5',
      'name': 'Daal Chawal (Lentil Rice)',
      'name_urdu': 'دال چاول',
      'brand': 'Traditional Pakistani',
      'category': 'legumes_dried',
      'co2_per_100g': 0.6,
      'serving_size_g': 300.0,
      'meal_type': 'Lunch',
      'eco_score': 'a',
    },
    {
      'id': 'pk_6',
      'name': 'Aloo Palak (Spinach Potato)',
      'name_urdu': 'آلو پالک',
      'brand': 'Traditional Pakistani',
      'category': 'vegetables_avg',
      'co2_per_100g': 0.4,
      'serving_size_g': 250.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'a',
    },
    {
      'id': 'pk_7',
      'name': 'Nihari (Beef Stew)',
      'name_urdu': 'نہاری',
      'brand': 'Traditional Pakistani',
      'category': 'beef',
      'co2_per_100g': 4.8,
      'serving_size_g': 350.0,
      'meal_type': 'Breakfast/Dinner',
      'eco_score': 'e',
    },
    {
      'id': 'pk_8',
      'name': 'Haleem (Lentil Meat Stew)',
      'name_urdu': 'حلیم',
      'brand': 'Traditional Pakistani',
      'category': 'beef',
      'co2_per_100g': 3.2,
      'serving_size_g': 300.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'd',
    },
    {
      'id': 'pk_9',
      'name': 'Chapli Kabab',
      'name_urdu': 'چپلی کباب',
      'brand': 'Traditional Pakistani',
      'category': 'beef',
      'co2_per_100g': 4.2,
      'serving_size_g': 200.0,
      'meal_type': 'Dinner',
      'eco_score': 'e',
    },
    {
      'id': 'pk_10',
      'name': 'Chicken Seekh Kabab',
      'name_urdu': 'چکن سیخ کباب',
      'brand': 'Traditional Pakistani',
      'category': 'poultry_chicken',
      'co2_per_100g': 1.6,
      'serving_size_g': 200.0,
      'meal_type': 'Dinner',
      'eco_score': 'c',
    },
    {
      'id': 'pk_11',
      'name': 'Samosa (Potato/Pea)',
      'name_urdu': 'سموسہ',
      'brand': 'Traditional Pakistani',
      'category': 'vegetables_avg',
      'co2_per_100g': 0.5,
      'serving_size_g': 150.0,
      'meal_type': 'Snack',
      'eco_score': 'b',
    },
    {
      'id': 'pk_12',
      'name': 'Aloo Paratha',
      'name_urdu': 'آلو پراٹھا',
      'brand': 'Traditional Pakistani',
      'category': 'wheat_bread',
      'co2_per_100g': 0.7,
      'serving_size_g': 200.0,
      'meal_type': 'Breakfast',
      'eco_score': 'b',
    },
    {
      'id': 'pk_13',
      'name': 'Tandoori Naan',
      'name_urdu': 'تندوری نان',
      'brand': 'Traditional Pakistani',
      'category': 'wheat_bread',
      'co2_per_100g': 0.4,
      'serving_size_g': 120.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'a',
    },
    {
      'id': 'pk_14',
      'name': 'Halwa Puri Chana',
      'name_urdu': 'حلوہ پوری چنا',
      'brand': 'Traditional Pakistani',
      'category': 'wheat_bread',
      'co2_per_100g': 0.9,
      'serving_size_g': 300.0,
      'meal_type': 'Breakfast',
      'eco_score': 'b',
    },
    {
      'id': 'pk_15',
      'name': 'Kheer (Rice Pudding)',
      'name_urdu': 'کھیر',
      'brand': 'Traditional Pakistani',
      'category': 'milk_dairy',
      'co2_per_100g': 1.1,
      'serving_size_g': 180.0,
      'meal_type': 'Snack',
      'eco_score': 'c',
    },
    {
      'id': 'pk_16',
      'name': 'Fish Fry (Lahori)',
      'name_urdu': 'لاہوری تلی مچھلی',
      'brand': 'Traditional Pakistani',
      'category': 'fish_wild',
      'co2_per_100g': 1.9,
      'serving_size_g': 250.0,
      'meal_type': 'Dinner',
      'eco_score': 'c',
    },
    {
      'id': 'pk_17',
      'name': 'Mix Sabzi (Assorted Veggies)',
      'name_urdu': 'مکس سبزی',
      'brand': 'Traditional Pakistani',
      'category': 'vegetables_avg',
      'co2_per_100g': 0.3,
      'serving_size_g': 250.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'a',
    },
    {
      'id': 'pk_18',
      'name': 'Chana Masala (Chickpeas)',
      'name_urdu': 'چنا مصالحہ',
      'brand': 'Traditional Pakistani',
      'category': 'legumes_dried',
      'co2_per_100g': 0.5,
      'serving_size_g': 250.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'a',
    },
    {
      'id': 'pk_19',
      'name': 'Siri Paye',
      'name_urdu': 'سری پائے',
      'brand': 'Traditional Pakistani',
      'category': 'beef',
      'co2_per_100g': 4.6,
      'serving_size_g': 350.0,
      'meal_type': 'Breakfast/Dinner',
      'eco_score': 'e',
    },
    {
      'id': 'pk_20',
      'name': 'Chicken Pulao',
      'name_urdu': 'چکن پلاؤ',
      'brand': 'Traditional Pakistani',
      'category': 'poultry_chicken',
      'co2_per_100g': 1.5,
      'serving_size_g': 350.0,
      'meal_type': 'Lunch/Dinner',
      'eco_score': 'c',
    },
  ];

  FoodService([this._supabase]);

  Future<List<OpenFoodFactsProduct>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();
    final List<OpenFoodFactsProduct> results = [];

    // Step 1: Query Supabase pakistani_foods primary DB (English, Urdu, Category)
    if (_supabase != null) {
      try {
        final List<dynamic> pkResponse = await _supabase
            .from('pakistani_foods')
            .select()
            .or('name.ilike.%$q%,name_urdu.ilike.%$q%,category.ilike.%$q%')
            .limit(15);

        if (pkResponse.isNotEmpty) {
          for (final item in pkResponse) {
            final m = Map<String, dynamic>.from(item as Map);
            final rawCat = m['category'] as String? ?? 'vegetables_avg';
            final normalizedCategory = EmissionFactors.normalizeCategory(
              rawCat,
            );
            final co2Val =
                (m['co2_per_100g'] as num?)?.toDouble() ??
                (m['co2_total'] as num?)?.toDouble() ??
                1.5;

            results.add(
              OpenFoodFactsProduct(
                id: (m['id'] ?? '').toString(),
                name: m['name'] as String? ?? '',
                nameUrdu: m['name_urdu'] as String?,
                brand: m['brand'] as String? ?? 'Traditional Pakistani',
                ecoScore: m['eco_score'] as String? ?? 'b',
                co2Total: co2Val,
                co2Per100g: co2Val,
                servingSizeG:
                    (m['serving_size_g'] as num?)?.toDouble() ?? 250.0,
                mealType: m['meal_type'] as String?,
                co2Source: m['co2_source'] as String?,
                fallbackCategory: normalizedCategory,
                source: 'Pakistani Food DB',
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
        final nameUrdu = (item['name_urdu'] as String? ?? '').toLowerCase();
        final category = (item['category'] as String).toLowerCase();
        return name.contains(q) || nameUrdu.contains(q) || category.contains(q);
      }).toList();

      for (final m in matchedLocal) {
        final rawCat = m['category'] as String;
        final normalizedCategory = EmissionFactors.normalizeCategory(rawCat);
        final co2Val = (m['co2_per_100g'] as num).toDouble();

        results.add(
          OpenFoodFactsProduct(
            id: m['id'] as String,
            name: m['name'] as String,
            nameUrdu: m['name_urdu'] as String?,
            brand: m['brand'] as String? ?? 'Traditional Pakistani',
            ecoScore: m['eco_score'] as String? ?? 'b',
            co2Total: co2Val,
            co2Per100g: co2Val,
            servingSizeG: (m['serving_size_g'] as num?)?.toDouble() ?? 250.0,
            mealType: m['meal_type'] as String?,
            fallbackCategory: normalizedCategory,
            source: 'Pakistani Food DB',
          ),
        );
      }
    }

    // Step 3: Fetch Open Food Facts as fallback or supplementary products
    try {
      final uri = Uri.parse(
        '$_baseUrl?search_terms=${Uri.encodeQueryComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=10',
      );
      final response = await _getWithRetry(uri);

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

  /// GET with a timeout and one retry on timeouts, network errors and 5xx
  /// responses (Open Food Facts is a free service and is occasionally slow).
  Future<http.Response> _getWithRetry(Uri uri) async {
    const headers = {'User-Agent': 'NeutrawiseApp/1.0'};
    const timeout = Duration(seconds: 8);
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(uri, headers: headers).timeout(timeout);
        if (response.statusCode < 500) return response;
        lastError = 'HTTP ${response.statusCode}';
      } catch (e) {
        lastError = e;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    throw lastError ?? 'Open Food Facts request failed';
  }
}
