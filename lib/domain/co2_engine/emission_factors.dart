class EmissionFactors {
  static const double gridIntensityPK = 0.45; // kg CO2e / kWh
  static const double naturalGasFactor = 0.20; // kg CO2e / kWh thermal
  
  static const Map<String, double> dietaryFactors = {
    'meat_heavy': 7.2,
    'omnivore': 5.5,
    'pescatarian': 4.0,
    'vegetarian': 3.8,
    'vegan': 2.9,
  };
  
  static const Map<String, double> baseTransportFactors = {
    'car_petrol_small': 0.18,
    'car_petrol_medium': 0.23,
    'car_petrol_large': 0.30,
    'car_diesel_small': 0.17,
    'car_diesel_medium': 0.22,
    'car_diesel_large': 0.28,
    'car_hybrid_medium': 0.15,
    'ev_efficiency': 0.18, // kWh / km
    'motorcycle': 0.10,
    'bus': 0.08,
    'train': 0.04,
    'metro': 0.03,
    'bicycle': 0.0,
    'walking': 0.0,
  };
  
  static const Map<String, double> vehicleAgeMultipliers = {
    'pre_2000': 1.15,
    '2000_2009': 1.05,
    '2010_2019': 0.95,
    'post_2020': 0.85,
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

  static String mapOFFCategoryToFactorKey(String categories) {
    final catLower = categories.toLowerCase();
    if (catLower.contains('beef') || catLower.contains('veal')) return 'beef';
    if (catLower.contains('shrimp') || catLower.contains('prawn')) return 'shrimp_farmed';
    if (catLower.contains('lamb') || catLower.contains('mutton')) return 'lamb_mutton';
    if (catLower.contains('butter')) return 'butter';
    if (catLower.contains('chocolate')) return 'chocolate';
    if (catLower.contains('pork') || catLower.contains('pig')) return 'pork';
    if (catLower.contains('chicken') || catLower.contains('poultry')) return 'poultry_chicken';
    if (catLower.contains('fish') || catLower.contains('seafood')) return 'fish_wild';
    if (catLower.contains('cheese')) return 'cheese';
    if (catLower.contains('milk') || catLower.contains('dairy')) return 'milk_dairy';
    if (catLower.contains('egg')) return 'eggs';
    if (catLower.contains('yogurt') || catLower.contains('yoghurt')) return 'yogurt';
    if (catLower.contains('tofu') || catLower.contains('soy')) return 'tofu';
    if (catLower.contains('rice')) return 'rice_white';
    if (catLower.contains('pasta') || catLower.contains('noodle')) return 'pasta';
    if (catLower.contains('bread') || catLower.contains('wheat')) return 'wheat_bread';
    if (catLower.contains('legume') || catLower.contains('lentil') || catLower.contains('bean')) return 'legumes_dried';
    if (catLower.contains('nut') || catLower.contains('almond')) return 'nuts_mixed';
    if (catLower.contains('coffee')) return 'coffee_brewed';
    if (catLower.contains('tea')) return 'tea';
    if (catLower.contains('potato')) return 'potatoes';
    if (catLower.contains('fruit')) return 'fruit_avg';
    if (catLower.contains('vegetable')) return 'vegetables_avg';
    return 'vegetables_avg';
  }
}
