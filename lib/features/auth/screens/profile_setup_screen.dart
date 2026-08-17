import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/sign_up_profile_input.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
import 'package:neutrawise/domain/co2_engine/co2_calculator.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Form states
  String _primaryTransport = 'car';
  String? _fuelType = 'petrol';
  String? _engineSize = 'medium';
  String? _vehicleAge = '2010_2019';
  String? _vehicleModel = '';
  double? _avgDailyKm = 15.0;

  // Residency & Country
  String _country = 'US';
  String _homeType = 'apartment_small';
  int _residents = 2;
  String _heatingType = 'natural_gas';
  bool _hasSolar = false;

  // Diet & Energy Details
  String _dietaryPreference = 'omnivore';
  double? _monthlyKwh = 300.0;
  bool _monthlyKwhUnknown = false;

  final _modelController = TextEditingController();
  final _kmController = TextEditingController(text: '15.0');
  final _kwhController = TextEditingController(text: '300.0');

  @override
  void dispose() {
    _modelController.dispose();
    _kmController.dispose();
    _kwhController.dispose();
    super.dispose();
  }

  void _submitProfile() async {
    setState(() => _isLoading = true);

    final input = SignUpProfileInput(
      primaryTransport: _primaryTransport,
      fuelType: _fuelType,
      engineSize: _engineSize,
      vehicleAge: _vehicleAge,
      vehicleModel: _vehicleModel,
      avgDailyKm: _avgDailyKm,
      homeType: _homeType,
      residents: _residents,
      monthlyKwh: _monthlyKwhUnknown ? null : _monthlyKwh,
      heatingType: _heatingType,
      hasSolar: _hasSolar,
      country: _country,
      dietaryPreference: _dietaryPreference,
    );

    final baselineData = CO2Calculator.processSignUpProfile(input);
    final user = ref.read(authProvider).user;

    if (user != null) {
      final profile = UserProfile(
        id: user.id,
        name:
            user.userMetadata?['name'] as String? ??
            user.email?.split('@').first ??
            'User',
        email: user.email,
        city: user.userMetadata?['city'] as String?,
        primaryTransport: _primaryTransport,
        fuelType: _fuelType,
        engineSize: _engineSize,
        vehicleAge: _vehicleAge,
        vehicleModel: _vehicleModel,
        avgDailyKm: _avgDailyKm,
        homeType: _homeType,
        residents: _residents,
        heatingType: _heatingType,
        hasSolar: _hasSolar,
        dietaryPreference: _dietaryPreference,
        countryCode: _country,
        transportFactor: baselineData['transport_factor'] as double?,
        dailyEnergyBaselineKwh:
            baselineData['daily_energy_baseline_kwh'] as double?,
        dailyEnergyBaselineCo2:
            baselineData['daily_energy_baseline_co2'] as double?,
        dailyHeatingBaselineCo2:
            baselineData['daily_heating_baseline_co2'] as double?,
        dailyFoodBaselineCo2:
            baselineData['daily_food_baseline_co2'] as double?,
        totalDailyBaselineCo2:
            baselineData['total_daily_baseline_co2'] as double?,
        gridIntensity: baselineData['grid_intensity'] as double?,
      );

      await ref.read(userRepositoryProvider).saveUserProfile(profile);
      if (mounted) {
        ref.read(authProvider.notifier).markProfileSetupComplete();
      }
    }
    setState(() => _isLoading = false);
  }

  bool _isMotorized() {
    return _primaryTransport == 'car' ||
        _primaryTransport == 'ev' ||
        _primaryTransport == 'motorcycle';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Your Profile')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _submitProfile();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          Step(
            title: const Text('Transport'),
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _primaryTransport,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Primary Transport',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'car',
                      child: Text('PETROL/DIESEL CAR'),
                    ),
                    DropdownMenuItem(
                      value: 'ev',
                      child: Text('ELECTRIC VEHICLE (EV)'),
                    ),
                    DropdownMenuItem(
                      value: 'motorcycle',
                      child: Text('MOTORCYCLE'),
                    ),
                    DropdownMenuItem(value: 'bus', child: Text('BUS')),
                    DropdownMenuItem(value: 'train', child: Text('TRAIN')),
                    DropdownMenuItem(value: 'metro', child: Text('METRO')),
                    DropdownMenuItem(value: 'bicycle', child: Text('BICYCLE')),
                    DropdownMenuItem(value: 'walking', child: Text('WALKING')),
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('NO DAILY TRANSPORT'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _primaryTransport = val!;
                      if (!_isMotorized()) {
                        _fuelType = null;
                        _engineSize = null;
                        _vehicleAge = null;
                        _vehicleModel = null;
                        _avgDailyKm = null;
                      } else {
                        _fuelType = _primaryTransport == 'ev'
                            ? 'electric'
                            : 'petrol';
                        _engineSize = 'medium';
                        _vehicleAge = '2010_2019';
                        _vehicleModel = '';
                        _avgDailyKm = 15.0;
                      }
                    });
                  },
                ),
                if (_isMotorized()) ...[
                  const SizedBox(height: 16),
                  if (_primaryTransport == 'car')
                    DropdownButtonFormField<String>(
                      initialValue: _fuelType,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Fuel Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'petrol',
                          child: Text('PETROL'),
                        ),
                        DropdownMenuItem(
                          value: 'diesel',
                          child: Text('DIESEL'),
                        ),
                        DropdownMenuItem(
                          value: 'hybrid',
                          child: Text('HYBRID'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _fuelType = val),
                    ),
                  if (_primaryTransport == 'car' ||
                      _primaryTransport == 'ev') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _engineSize,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _primaryTransport == 'ev'
                            ? 'Battery Size'
                            : 'Engine Size (Litres)',
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'small',
                          child: Text('SMALL (< 1.4L / Compact EV)'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('MEDIUM (1.4L - 2.0L / Mid-size EV)'),
                        ),
                        DropdownMenuItem(
                          value: 'large',
                          child: Text('LARGE (> 2.0L / Large SUV EV)'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _engineSize = val),
                    ),
                  ],
                  if (_primaryTransport != 'ev') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _vehicleAge,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Age',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pre_2010',
                          child: Text('BEFORE 2010'),
                        ),
                        DropdownMenuItem(
                          value: '2010_2019',
                          child: Text('2010 - 2019'),
                        ),
                        DropdownMenuItem(
                          value: '2020_plus',
                          child: Text('2020 OR NEWER'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _vehicleAge = val),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Model (Display Name)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _vehicleModel = val,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _kmController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Average Daily Commute (km)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _avgDailyKm = double.tryParse(val) ?? 15.0,
                  ),
                ],
              ],
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Residency & Country'),
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _country,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Country Code',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'US',
                      child: Text('UNITED STATES (US)'),
                    ),
                    DropdownMenuItem(
                      value: 'GB',
                      child: Text('UNITED KINGDOM (GB)'),
                    ),
                    DropdownMenuItem(value: 'DE', child: Text('GERMANY (DE)')),
                    DropdownMenuItem(value: 'PK', child: Text('PAKISTAN (PK)')),
                  ],
                  onChanged: (val) => setState(() => _country = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _homeType,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Home Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'apartment_small',
                      child: Text('SMALL APARTMENT / FLAT'),
                    ),
                    DropdownMenuItem(
                      value: 'apartment_large',
                      child: Text('LARGE APARTMENT / FLAT'),
                    ),
                    DropdownMenuItem(
                      value: 'house_small',
                      child: Text('SMALL HOUSE'),
                    ),
                    DropdownMenuItem(
                      value: 'house_medium',
                      child: Text('MEDIUM HOUSE'),
                    ),
                    DropdownMenuItem(
                      value: 'house_large',
                      child: Text('LARGE HOUSE'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _homeType = val!),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Number of Residents:'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _residents > 1
                              ? () => setState(() => _residents--)
                              : null,
                        ),
                        Text(
                          '$_residents',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _residents++),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _heatingType,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Heating Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'natural_gas',
                      child: Text('NATURAL GAS'),
                    ),
                    DropdownMenuItem(
                      value: 'electric',
                      child: Text('ELECTRICITY'),
                    ),
                    DropdownMenuItem(
                      value: 'heat_pump',
                      child: Text('HEAT PUMP'),
                    ),
                    DropdownMenuItem(value: 'lpg', child: Text('LPG')),
                    DropdownMenuItem(value: 'oil', child: Text('HEATING OIL')),
                    DropdownMenuItem(
                      value: 'district',
                      child: Text('DISTRICT HEATING'),
                    ),
                    DropdownMenuItem(
                      value: 'biomass_wood',
                      child: Text('BIOMASS / WOOD'),
                    ),
                    DropdownMenuItem(value: 'coal', child: Text('COAL')),
                  ],
                  onChanged: (val) => setState(() => _heatingType = val!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Has Solar Panels?'),
                  value: _hasSolar,
                  onChanged: (val) => setState(() => _hasSolar = val),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Diet & Energy Details'),
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _dietaryPreference,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Dietary Preference',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'vegan', child: Text('VEGAN')),
                    DropdownMenuItem(
                      value: 'vegetarian',
                      child: Text('VEGETARIAN'),
                    ),
                    DropdownMenuItem(
                      value: 'pescatarian',
                      child: Text('PESCATARIAN'),
                    ),
                    DropdownMenuItem(
                      value: 'flexitarian',
                      child: Text('FLEXITARIAN'),
                    ),
                    DropdownMenuItem(
                      value: 'omnivore',
                      child: Text('OMNIVORE'),
                    ),
                    DropdownMenuItem(
                      value: 'carnivore',
                      child: Text('CARNIVORE'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _dietaryPreference = val!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kwhController,
                  enabled: !_monthlyKwhUnknown,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Electricity (kWh)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      _monthlyKwh = double.tryParse(val) ?? 300.0,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text(
                    "I don't know my usage (use typical estimates)",
                  ),
                  value: _monthlyKwhUnknown,
                  onChanged: (val) {
                    setState(() {
                      _monthlyKwhUnknown = val!;
                      if (_monthlyKwhUnknown) {
                        _kwhController.clear();
                      } else {
                        _kwhController.text = '300.0';
                        _monthlyKwh = 300.0;
                      }
                    });
                  },
                ),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
        ],
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: _currentStep == 2 ? 'Finish Setup' : 'Next',
                    onPressed: details.onStepContinue ?? () {},
                    isLoading: _isLoading,
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
