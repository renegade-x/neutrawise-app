import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/domain/models/sign_up_profile_input.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
import 'package:neutrawise/domain/co2_engine/co2_calculator.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';

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
  String _homeType = 'apartment';
  int _residents = 2;
  double _monthlyKwh = 300;
  String _heatingType = 'natural_gas';
  bool _hasSolar = false;
  String _dietaryPreference = 'omnivore';

  void _submitProfile() async {
    setState(() => _isLoading = true);
    
    final input = SignUpProfileInput(
      primaryTransport: _primaryTransport,
      homeType: _homeType,
      residents: _residents,
      monthlyKwh: _monthlyKwh,
      heatingType: _heatingType,
      hasSolar: _hasSolar,
      dietaryPreference: _dietaryPreference,
    );

    final baselineData = CO2Calculator.processSignUpProfile(input);
    final user = ref.read(authProvider).user;

    if (user != null) {
      final profile = UserProfile(
        id: user.id,
        name: user.email?.split('@').first ?? 'User',
        email: user.email,
        primaryTransport: _primaryTransport,
        homeType: _homeType,
        residents: _residents,
        heatingType: _heatingType,
        hasSolar: _hasSolar,
        dietaryPreference: _dietaryPreference,
        transportFactor: baselineData['transport_factor'],
        dailyEnergyBaselineKwh: baselineData['daily_energy_baseline_kwh'],
        dailyEnergyBaselineCo2: baselineData['daily_energy_baseline_co2'],
        dailyHeatingBaselineCo2: baselineData['daily_heating_baseline_co2'],
        dailyFoodBaselineCo2: baselineData['daily_food_baseline_co2'],
        totalDailyBaselineCo2: baselineData['total_daily_baseline_co2'],
      );

      await ref.read(userRepositoryProvider).saveUserProfile(profile);
      if (mounted) {
        context.push('/dashboard');
      }
    }
    setState(() => _isLoading = false);
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
            content: DropdownButtonFormField<String>(
              value: _primaryTransport,
              items: ['car', 'motorcycle', 'bus', 'train', 'bicycle', 'walking'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _primaryTransport = val!),
              decoration: const InputDecoration(labelText: 'Primary Transport'),
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Energy'),
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _homeType,
                  items: ['apartment', 'house'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                  onChanged: (val) => setState(() => _homeType = val!),
                  decoration: const InputDecoration(labelText: 'Home Type'),
                ),
                TextFormField(
                  initialValue: '$_monthlyKwh',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly Electricity (kWh)'),
                  onChanged: (val) => _monthlyKwh = double.tryParse(val) ?? 300,
                ),
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
            title: const Text('Food'),
            content: DropdownButtonFormField<String>(
              value: _dietaryPreference,
              items: ['meat_heavy', 'omnivore', 'pescatarian', 'vegetarian', 'vegan'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _dietaryPreference = val!),
              decoration: const InputDecoration(labelText: 'Dietary Preference'),
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
                    text: _currentStep == 2 ? 'Finish Setup' : 'Continue',
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
