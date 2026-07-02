import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/models/sign_up_profile_input.dart';
import 'package:neutrawise/domain/co2_engine/co2_calculator.dart';

void main() {
  group('CO2Calculator Tests', () {
    test(
      'Calculates baselines correctly for a petrol car and carnivore diet',
      () {
        final input = SignUpProfileInput(
          primaryTransport: 'car',
          fuelType: 'petrol',
          engineSize: 'medium',
          vehicleAge: '2010_2019',
          avgDailyKm: 20.0,
          homeType: 'house_medium',
          residents: 4,
          monthlyKwh: 400.0,
          heatingType: 'natural_gas',
          hasSolar: false,
          country: 'PK',
          dietaryPreference: 'carnivore',
        );

        final result = CO2Calculator.processSignUpProfile(input);

        // Transport factor: 0.23 (base petrol medium) * 1.0 (2010_2019 multiplier) = 0.23
        final expectedTransportFactor = 0.23 * 1.0;
        expect(
          result['transport_factor'],
          closeTo(expectedTransportFactor, 0.001),
        );

        // Daily transport CO2: 20 * 0.23 = 4.60
        expect(result['daily_transport_co2'], closeTo(4.6, 0.001));

        // Daily energy kWh: (400 / 30) / 4 = 3.333 kWh
        final expectedDailyKwh = (400.0 / 30.0) / 4.0;
        expect(
          result['daily_energy_baseline_kwh'],
          closeTo(expectedDailyKwh, 0.001),
        );

        // Daily heating CO2: (35.0 * 0.667 / 4) * 0.202 = 1.1789 kg
        final expectedHeatingCo2 = (35.0 * 0.667 / 4) * 0.202;
        expect(
          result['daily_heating_baseline_co2'],
          closeTo(expectedHeatingCo2, 0.001),
        );

        // Daily energy CO2: (3.333 * 0.45) + 1.1789 = 2.6789
        final expectedElectricityCo2 = expectedDailyKwh * 0.45;
        expect(
          result['daily_energy_baseline_co2'],
          closeTo(expectedElectricityCo2 + expectedHeatingCo2, 0.001),
        );

        // Daily food CO2: 7.2 (carnivore)
        expect(result['daily_food_baseline_co2'], 7.2);

        // Total: 4.60 + 2.6789 + 7.2 = 14.4789
        final expectedTotal =
            4.60 + expectedElectricityCo2 + expectedHeatingCo2 + 7.2;
        expect(
          result['total_daily_baseline_co2'],
          closeTo(expectedTotal, 0.001),
        );
      },
    );

    test('Calculates baselines correctly for EV and vegan with solar', () {
      final input = SignUpProfileInput(
        primaryTransport: 'ev',
        engineSize: 'medium',
        avgDailyKm: 15.0,
        homeType: 'apartment_small',
        residents: 2,
        monthlyKwh: 300.0,
        heatingType: 'electric',
        hasSolar: true,
        country: 'PK',
        dietaryPreference: 'vegan',
      );

      final result = CO2Calculator.processSignUpProfile(input);

      // EV transport factor = 0.18 (ev efficiency) * 0.45 (grid intensity) = 0.081
      final expectedTransportFactor = 0.18 * 0.45;
      expect(
        result['transport_factor'],
        closeTo(expectedTransportFactor, 0.001),
      );

      // Daily transport: 15 * 0.081 = 1.215
      expect(result['daily_transport_co2'], closeTo(1.215, 0.001));

      // Solar adjusted monthly Kwh = 300 * 0.75 = 225
      // Daily Kwh per person = (225 / 30) / 2 = 3.75
      expect(result['daily_energy_baseline_kwh'], closeTo(3.75, 0.001));

      // Daily energy CO2: 3.75 * 0.45 = 1.6875
      expect(result['daily_energy_baseline_co2'], closeTo(1.6875, 0.001));

      // Daily heating CO2: 0 (electric)
      expect(result['daily_heating_baseline_co2'], 0.0);

      // Daily food CO2: 1.5 (vegan)
      expect(result['daily_food_baseline_co2'], 1.5);

      // Total: 1.215 + 1.6875 + 0 + 1.5 = 4.4025
      expect(result['total_daily_baseline_co2'], closeTo(4.4025, 0.001));
    });
  });
}
