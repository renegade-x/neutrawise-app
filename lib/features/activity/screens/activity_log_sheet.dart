import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/domain/co2_engine/co2_calculator.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/sync/sync_manager.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';
import 'package:neutrawise/data/services/open_food_facts_service.dart';
import 'package:neutrawise/domain/co2_engine/emission_factors.dart';

class ActivityLogSheet extends ConsumerStatefulWidget {
  final DailyLog? existingLog;

  const ActivityLogSheet({super.key, this.existingLog});

  @override
  ConsumerState<ActivityLogSheet> createState() => _ActivityLogSheetState();
}

class _ActivityLogSheetState extends ConsumerState<ActivityLogSheet> {
  List<TransportEntry> _transportEntries = [];
  List<FoodEntry> _foodEntries = [];
  List<String> _energyDeviations = [];
  bool _energyConfirmed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingLog != null) {
      _transportEntries = List.from(widget.existingLog!.transportEntries);
      _foodEntries = List.from(widget.existingLog!.foodEntries);
      _energyDeviations = List.from(widget.existingLog!.energyDeviations);
      _energyConfirmed =
          widget.existingLog!.energyCo2 > 0 || _energyDeviations.isNotEmpty;
      // simplified energy confirmed check for existing log
    }
  }

  // Temp form states
  String _transportMode = 'car';
  final _distanceCtrl = TextEditingController();

  String _mealSlot = 'Lunch';
  final _foodNameCtrl = TextEditingController();
  String _foodCategory = 'vegetables_avg';
  final String _servingSize = 'medium';
  final _foodGramsCtrl = TextEditingController(text: '250');
  OpenFoodFactsProduct? _selectedFoodProduct;

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _foodNameCtrl.dispose();
    _foodGramsCtrl.dispose();
    super.dispose();
  }

  void _submitLog() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).user;
      final profile = await ref
          .read(userRepositoryProvider)
          .getUserProfile(user!.id);

      final date = DateTime.now().toIso8601String().substring(0, 10);

      final log = CO2Calculator.processDailyLog(
        profile!,
        date,
        _transportEntries,
        _foodEntries,
        _energyDeviations,
        _energyConfirmed,
        profile.currentStreak,
      );

      await ref.read(syncManagerProvider).saveLog(log);

      final xpDelta = log.xpEarned - (widget.existingLog?.xpEarned ?? 0);
      final savedDelta =
          log.co2SavedVsBaseline -
          (widget.existingLog?.co2SavedVsBaseline ?? 0.0);
      final isFirstLogOfDay = widget.existingLog == null;

      final updatedProfile = profile.copyWith(
        xp: profile.xp + xpDelta,
        currentStreak: isFirstLogOfDay
            ? profile.currentStreak + 1
            : profile.currentStreak,
        totalCo2Saved: profile.totalCo2Saved + savedDelta,
      );
      await ref.read(userRepositoryProvider).saveUserProfile(updatedProfile);

      if (mounted) {
        // Force Dashboard to refresh manually in case Realtime isn't enabled in Supabase Cloud
        ref.invalidate(recentLogsProvider(user.id));
        ref.invalidate(userProfileProvider(user.id));

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Log saved! +${log.xpEarned} XP',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.directions_car)),
                Tab(icon: Icon(Icons.restaurant)),
                Tab(icon: Icon(Icons.bolt)),
              ],
              indicatorColor: AppColors.primaryGreen,
              labelColor: AppColors.primaryGreen,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTransportTab(),
                  _buildFoodTab(),
                  _buildEnergyTab(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PrimaryButton(
                text: 'Save Today\'s Log',
                isLoading: _isLoading,
                onPressed: _submitLog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _transportMode,
            dropdownColor: AppColors.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Transport Mode',
              border: OutlineInputBorder(),
            ),
            items:
                [
                      'car',
                      'ev',
                      'motorcycle',
                      'bus',
                      'train',
                      'metro',
                      'bicycle',
                      'walking',
                    ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toUpperCase()),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _transportMode = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _distanceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Trip'),
            onPressed: () {
              final dist = double.tryParse(_distanceCtrl.text);
              if (dist != null && dist > 0) {
                setState(() {
                  _transportEntries.add(
                    TransportEntry(mode: _transportMode, distanceKm: dist),
                  );
                  _distanceCtrl.clear();
                });
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Today\'s Trips:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ..._transportEntries.map(
            (e) => ListTile(
              title: Text(e.mode.toUpperCase()),
              trailing: Text('${e.distanceKm} km'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mealSlot,
            dropdownColor: AppColors.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Meal',
              border: OutlineInputBorder(),
            ),
            items: [
              'Breakfast',
              'Lunch',
              'Dinner',
              'Snack',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _mealSlot = v!),
          ),
          const SizedBox(height: 16),
          Autocomplete<OpenFoodFactsProduct>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<OpenFoodFactsProduct>.empty();
              }
              final service = ref.read(openFoodFactsProvider);
              return await service.searchFood(textEditingValue.text);
            },
            displayStringForOption: (OpenFoodFactsProduct option) =>
                option.name,
            onSelected: (OpenFoodFactsProduct selection) {
              _foodNameCtrl.text = selection.name;
              _selectedFoodProduct = selection;
              if (selection.fallbackCategory != null) {
                setState(() => _foodCategory = selection.fallbackCategory!);
              }
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  // Only override controller if it's empty to not lose user text
                  controller.addListener(() {
                    if (_foodNameCtrl.text != controller.text) {
                      _selectedFoodProduct = null;
                    }
                    _foodNameCtrl.text = controller.text;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Food Name (Search)',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  color: AppColors.surfaceDark,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 300,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(
                            option.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            option.brand ?? '',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _foodCategory,
            dropdownColor: AppColors.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: EmissionFactors.foodCategoryFactors.keys
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.replaceAll('_', ' ').toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _foodCategory = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _foodGramsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (grams)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Meal'),
            onPressed: () {
              final grams = double.tryParse(_foodGramsCtrl.text);
              if (grams != null && grams > 0 && _foodNameCtrl.text.isNotEmpty) {
                setState(() {
                  _foodEntries.add(
                    FoodEntry(
                      mealSlot: _mealSlot,
                      foodName: _foodNameCtrl.text,
                      category: _foodCategory,
                      servingSize: _servingSize,
                      grams: grams,
                      co2Per100g: _selectedFoodProduct?.co2Total,
                      offBarcode: _selectedFoodProduct?.id,
                    ),
                  );
                  _foodNameCtrl.clear();
                  _selectedFoodProduct = null;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Today\'s Meals:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ..._foodEntries.map(
            (e) => ListTile(
              title: Text('${e.mealSlot}: ${e.foodName}'),
              subtitle: Text(e.category),
              trailing: Text('${e.grams}g'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyTab() {
    final devOptions = [
      'more_than_usual',
      'less_than_usual',
      'no_ac',
      'cold_showers',
      'unplugged_devices',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Confirm Energy Usage for Today'),
            subtitle: const Text('Required to complete full daily log'),
            value: _energyConfirmed,
            activeTrackColor: AppColors.primaryGreen,
            onChanged: (v) => setState(() => _energyConfirmed = v),
          ),
          const SizedBox(height: 16),
          const Text('Any special deviations today?'),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: devOptions.map((opt) {
              final isSelected = _energyDeviations.contains(opt);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: CheckboxListTile(
                  title: Text(opt.replaceAll('_', ' ')),
                  value: isSelected,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _energyDeviations.add(opt);
                      } else {
                        _energyDeviations.remove(opt);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
