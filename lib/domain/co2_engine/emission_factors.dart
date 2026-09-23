class EmissionFactors {
  static const double gridIntensityPK = 0.45; // kg CO2e / kWh
  static const double naturalGasFactor = 0.202; // kg CO2e / kWh thermal

  static const Map<String, double> gridIntensityByCountry = {
    'PK': 0.45,
    'US': 0.38,
    'GB': 0.25,
    'DE': 0.18,
  };

  static const Map<String, double> heatingFactors = {
    'natural_gas': 0.202,
    'lpg': 0.227,
    'oil': 0.268,
    'district': 0.080,
    'biomass_wood': 0.015,
    'coal': 0.354,
    'electric': 0.0,
    'heat_pump': 0.0,
  };

  static const Map<String, double> baseDailyKwhByHome = {
    'apartment_small': 8.0,
    'apartment_large': 12.0,
    'house_small': 15.0,
    'house_medium': 22.0,
    'house_large': 30.0,
  };

  static const Map<String, double> heatingKwhByHome = {
    'apartment_small': 12.0,
    'apartment_large': 18.0,
    'house_small': 25.0,
    'house_medium': 35.0,
    'house_large': 50.0,
  };

  static const Map<String, double> evEfficiencyKwhPerKm = {
    'small': 0.15,
    'medium': 0.18,
    'large': 0.22,
  };

  static const Map<String, double> dietaryFactors = {
    'vegan': 1.5,
    'vegetarian': 2.5,
    'pescatarian': 3.4,
    'flexitarian': 4.2,
    'omnivore': 5.5,
    'carnivore': 7.2,
  };

  static const Map<String, double> baseTransportFactors = {
    'car_petrol_small': 0.18,
    'car_petrol_medium': 0.23,
    'car_petrol_large': 0.28,
    'car_diesel_small': 0.17,
    'car_diesel_medium': 0.22,
    'car_diesel_large': 0.27,
    'car_hybrid_medium': 0.12,
    'motorcycle': 0.10,
    'bus': 0.089,
    'train': 0.041,
    'metro': 0.035,
    'bicycle': 0.0,
    'walking': 0.0,
  };

  static const Map<String, double> vehicleAgeMultipliers = {
    'pre_2010': 1.15,
    '2010_2019': 1.00,
    '2020_plus': 0.85,
  };

  static const Map<String, double> foodCategoryFactors = {
    'beef': 60.0,
    'shrimp_farmed': 26.9,
    'lamb_mutton': 39.2,
    'butter': 23.8,
    'chocolate': 19.0,
    'pork': 12.3,
    'poultry_chicken': 9.9,
    'fish_wild': 3.0,
    'cheese': 21.0,
    'milk_dairy': 3.2,
    'eggs': 4.5,
    'yogurt': 2.9,
    'tofu': 3.0,
    'rice_white': 4.0,
    'pasta': 1.9,
    'wheat_bread': 1.6,
    'legumes_dried': 0.9,
    'nuts_mixed': 2.3,
    'coffee_brewed': 17.0,
    'tea': 3.5,
    'potatoes': 0.46,
    'vegetables_avg': 0.4,
    'fruit_avg': 0.7,
  };

  static String normalizeCategory(String? category) {
    if (category == null || category.trim().isEmpty) {
      return 'vegetables_avg';
    }
    final catLower = category.trim().toLowerCase();

    // If already exact key in foodCategoryFactors, return directly
    if (foodCategoryFactors.containsKey(catLower)) {
      return catLower;
    }

    if (catLower.contains('beef') ||
        catLower.contains('veal') ||
        catLower.contains('nihari') ||
        catLower.contains('paye') ||
        catLower.contains('chapli')) {
      return 'beef';
    }
    if (catLower.contains('shrimp') || catLower.contains('prawn')) {
      return 'shrimp_farmed';
    }
    if (catLower.contains('lamb') ||
        catLower.contains('mutton') ||
        catLower.contains('karahi_mutton')) {
      return 'lamb_mutton';
    }
    if (catLower.contains('butter') || catLower.contains('ghee')) {
      return 'butter';
    }
    if (catLower.contains('chocolate')) return 'chocolate';
    if (catLower.contains('pork') || catLower.contains('bacon')) return 'pork';
    if (catLower.contains('chicken') ||
        catLower.contains('poultry') ||
        catLower.contains('seekh') ||
        catLower.contains('biryani_chicken')) {
      return 'poultry_chicken';
    }
    if (catLower.contains('fish') ||
        catLower.contains('seafood') ||
        catLower.contains('machli')) {
      return 'fish_wild';
    }
    if (catLower.contains('cheese') || catLower.contains('paneer')) {
      return 'cheese';
    }
    if (catLower.contains('milk') ||
        catLower.contains('dairy') ||
        catLower.contains('kheer') ||
        catLower.contains('lassi')) {
      return 'milk_dairy';
    }
    if (catLower.contains('egg') || catLower.contains('anda')) return 'eggs';
    if (catLower.contains('yogurt') ||
        catLower.contains('yoghurt') ||
        catLower.contains('dahi') ||
        catLower.contains('raita')) {
      return 'yogurt';
    }
    if (catLower.contains('tofu') || catLower.contains('soy')) return 'tofu';
    if (catLower.contains('rice') ||
        catLower.contains('pulao') ||
        catLower.contains('chawal') ||
        catLower.contains('biryani')) {
      return 'rice_white';
    }
    if (catLower.contains('pasta') || catLower.contains('noodle')) {
      return 'pasta';
    }
    if (catLower.contains('grain') ||
        catLower.contains('bread') ||
        catLower.contains('wheat') ||
        catLower.contains('roti') ||
        catLower.contains('naan') ||
        catLower.contains('paratha') ||
        catLower.contains('puri') ||
        catLower.contains('flour') ||
        catLower.contains('halwa')) {
      return 'wheat_bread';
    }
    if (catLower.contains('legume') ||
        catLower.contains('lentil') ||
        catLower.contains('bean') ||
        catLower.contains('daal') ||
        catLower.contains('chana') ||
        catLower.contains('haleem')) {
      return 'legumes_dried';
    }
    if (catLower.contains('nut') ||
        catLower.contains('almond') ||
        catLower.contains('peanut') ||
        catLower.contains('walnut')) {
      return 'nuts_mixed';
    }
    if (catLower.contains('coffee')) return 'coffee_brewed';
    if (catLower.contains('tea') || catLower.contains('chai')) return 'tea';
    if (catLower.contains('potato') || catLower.contains('aloo')) {
      return 'potatoes';
    }
    if (catLower.contains('fruit') ||
        catLower.contains('apple') ||
        catLower.contains('mango') ||
        catLower.contains('banana') ||
        catLower.contains('orange')) {
      return 'fruit_avg';
    }
    if (catLower.contains('vegetable') ||
        catLower.contains('veggie') ||
        catLower.contains('sabzi') ||
        catLower.contains('palak') ||
        catLower.contains('salad') ||
        catLower.contains('snack')) {
      return 'vegetables_avg';
    }
    return 'vegetables_avg';
  }

  static String mapOFFCategoryToFactorKey(String categories) {
    return normalizeCategory(categories);
  }

  static double calculateFoodCo2({
    required double grams,
    required String category,
    double? co2Factor,
  }) {
    if (grams <= 0) return 0.0;

    double factorKgPerKg;
    if (co2Factor != null && co2Factor > 0) {
      if (co2Factor > 50.0) {
        // Provided in grams of CO2 per 100g (e.g. 180g -> 1.8 kg CO2/kg)
        factorKgPerKg = co2Factor / 100.0;
      } else {
        // Provided in kg CO2 per kg / 1000g (e.g. 1.8 kg/kg for Chicken Biryani)
        factorKgPerKg = co2Factor;
      }
    } else {
      final normalizedCat = normalizeCategory(category);
      factorKgPerKg = foodCategoryFactors[normalizedCat] ?? 0.4;
    }

    return factorKgPerKg * (grams / 1000.0);
  }
}
