import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingProfile();
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _kmController.dispose();
    _kwhController.dispose();
    super.dispose();
  }

  String _validOrFallback(
    String? val,
    List<String> validOptions,
    String fallback,
  ) {
    if (val == null) return fallback;
    final trimmed = val.trim();
    if (validOptions.contains(trimmed)) return trimmed;
    final lower = trimmed.toLowerCase();
    for (var opt in validOptions) {
      if (opt.toLowerCase() == lower) return opt;
    }
    return fallback;
  }

  void _loadExistingProfile() async {
    final user = ref.read(authProvider).user;
    if (user != null) {
      final profile = await ref
          .read(userRepositoryProvider)
          .getUserProfile(user.id);
      if (profile != null && mounted) {
        setState(() {
          _primaryTransport = _validOrFallback(profile.primaryTransport, [
            'car',
            'ev',
            'motorcycle',
            'bus',
            'train',
            'metro',
            'bicycle',
            'walking',
            'none',
          ], 'car');
          if (_isMotorized()) {
            _fuelType = _validOrFallback(profile.fuelType, [
              'petrol',
              'diesel',
              'hybrid',
              'electric',
            ], 'petrol');
            _engineSize = _validOrFallback(profile.engineSize, [
              'small',
              'medium',
              'large',
            ], 'medium');
            _vehicleAge = _validOrFallback(profile.vehicleAge, [
              'pre_2010',
              '2010_2019',
              '2020_plus',
            ], '2010_2019');
            _vehicleModel = profile.vehicleModel ?? '';
            _modelController.text = _vehicleModel ?? '';
            _avgDailyKm = profile.avgDailyKm ?? 15.0;
            _kmController.text = _avgDailyKm.toString();
          }

          _country = _validOrFallback(profile.countryCode?.toUpperCase(), [
            'US',
            'GB',
            'DE',
            'PK',
          ], 'US');
          _homeType = _validOrFallback(profile.homeType, [
            'apartment_small',
            'apartment_large',
            'house_small',
            'house_medium',
            'house_large',
          ], 'apartment_small');
          _residents = profile.residents ?? 2;
          _heatingType = _validOrFallback(profile.heatingType, [
            'natural_gas',
            'electric',
            'heat_pump',
            'lpg',
            'oil',
            'district',
            'biomass_wood',
            'coal',
          ], 'natural_gas');
          _hasSolar = profile.hasSolar ?? false;

          _dietaryPreference = _validOrFallback(profile.dietaryPreference, [
            'vegan',
            'vegetarian',
            'pescatarian',
            'flexitarian',
            'omnivore',
            'carnivore',
          ], 'omnivore');

          if (profile.dailyEnergyBaselineKwh != null &&
              profile.dailyEnergyBaselineKwh! > 0) {
            _monthlyKwh = (profile.dailyEnergyBaselineKwh! * 30.0);
            _kwhController.text = _monthlyKwh!.toStringAsFixed(1);
            _monthlyKwhUnknown = false;
          }
        });
      }
    }
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
      final userRepo = ref.read(userRepositoryProvider);
      final existingProfile = await userRepo.getUserProfile(user.id);

      final profile =
          (existingProfile ??
                  UserProfile(
                    id: user.id,
                    name:
                        user.userMetadata?['name'] as String? ??
                        user.email?.split('@').first ??
                        'User',
                    email: user.email,
                    city: user.userMetadata?['city'] as String?,
                  ))
              .copyWith(
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

      await userRepo.saveUserProfile(profile);
      ref.invalidate(userProfileProvider(user.id));

      if (mounted) {
        ref.read(authProvider.notifier).markProfileSetupComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Baseline profile updated successfully!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/dashboard');
        }
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
    final hasSetup = ref.watch(authProvider).hasProfileSetup;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final surfaceColor = AppColors.surface(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          hasSetup ? 'Edit Profile & Baseline' : 'Setup Your Profile',
          style: TextStyle(color: textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.primaryGreen),
        ),
        child: Stepper(
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
              title: Text(
                'Transport',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _primaryTransport,
                    dropdownColor: surfaceColor,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Primary Transport',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
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
                      DropdownMenuItem(
                        value: 'bicycle',
                        child: Text('BICYCLE'),
                      ),
                      DropdownMenuItem(
                        value: 'walking',
                        child: Text('WALKING'),
                      ),
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
                        dropdownColor: surfaceColor,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Fuel Type',
                          labelStyle: TextStyle(color: textSecondary),
                          border: const OutlineInputBorder(),
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
                        dropdownColor: surfaceColor,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: _primaryTransport == 'ev'
                              ? 'Battery Size'
                              : 'Engine Size (Litres)',
                          labelStyle: TextStyle(color: textSecondary),
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
                        dropdownColor: surfaceColor,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Vehicle Age',
                          labelStyle: TextStyle(color: textSecondary),
                          border: const OutlineInputBorder(),
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
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Vehicle Model (Display Name)',
                        labelStyle: TextStyle(color: textSecondary),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => _vehicleModel = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _kmController,
                      style: TextStyle(color: textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Average Daily Commute (km)',
                        labelStyle: TextStyle(color: textSecondary),
                        border: const OutlineInputBorder(),
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
              title: Text(
                'Residency & Country',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    dropdownColor: surfaceColor,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Country Code',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
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
                      DropdownMenuItem(
                        value: 'DE',
                        child: Text('GERMANY (DE)'),
                      ),
                      DropdownMenuItem(
                        value: 'PK',
                        child: Text('PAKISTAN (PK)'),
                      ),
                    ],
                    onChanged: (val) => setState(() => _country = val!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _homeType,
                    dropdownColor: surfaceColor,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Home Type',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
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
                      Text(
                        'Number of Residents:',
                        style: TextStyle(color: textPrimary),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, color: textPrimary),
                            onPressed: _residents > 1
                                ? () => setState(() => _residents--)
                                : null,
                          ),
                          Text(
                            '$_residents',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: textPrimary),
                            onPressed: () => setState(() => _residents++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _heatingType,
                    dropdownColor: surfaceColor,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Heating Type',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
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
                      DropdownMenuItem(
                        value: 'oil',
                        child: Text('HEATING OIL'),
                      ),
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
                    title: Text(
                      'Has Solar Panels?',
                      style: TextStyle(color: textPrimary),
                    ),
                    value: _hasSolar,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (val) => setState(() => _hasSolar = val),
                  ),
                ],
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: Text(
                'Diet & Energy Details',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _dietaryPreference,
                    dropdownColor: surfaceColor,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Dietary Preference',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
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
                    onChanged: (val) =>
                        setState(() => _dietaryPreference = val!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _kwhController,
                    enabled: !_monthlyKwhUnknown,
                    style: TextStyle(color: textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monthly Electricity (kWh)',
                      labelStyle: TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _monthlyKwh = double.tryParse(val) ?? 300.0,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: Text(
                      "I don't know my usage (use typical estimates)",
                      style: TextStyle(color: textPrimary),
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
      ),
    );
  }
}
