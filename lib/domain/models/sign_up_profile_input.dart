class SignUpProfileInput {
  final String primaryTransport;
  final String? fuelType;
  final String? engineSize;
  final String? vehicleAge;
  final String? vehicleModel;
  final double? avgDailyKm;

  final String homeType;
  final int residents;
  final double? monthlyKwh;
  final String heatingType;
  final bool hasSolar;
  final String country;

  final String dietaryPreference;

  SignUpProfileInput({
    required this.primaryTransport,
    this.fuelType,
    this.engineSize,
    this.vehicleAge,
    this.vehicleModel,
    this.avgDailyKm,
    required this.homeType,
    required this.residents,
    this.monthlyKwh,
    required this.heatingType,
    required this.hasSolar,
    required this.country,
    required this.dietaryPreference,
  });
}
