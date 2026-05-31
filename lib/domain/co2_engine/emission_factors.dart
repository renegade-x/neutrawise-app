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
}
