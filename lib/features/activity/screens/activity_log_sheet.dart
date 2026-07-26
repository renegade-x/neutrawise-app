import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/widgets/celebration_modal.dart';
import 'package:neutrawise/routing/router.dart';

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

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _addTransportTrip() {
    final text = _distanceCtrl.text.trim();
    if (text.isEmpty) {
      _showSnackbar('Please enter a trip distance in kilometers.');
      return;
    }
    final dist = double.tryParse(text);
    if (dist == null) {
      _showSnackbar('Invalid distance format. Please enter a valid number.');
      return;
    }
    if (dist <= 0) {
      _showSnackbar('Distance must be greater than 0 km.');
      return;
    }
    if (dist > 2000) {
      _showSnackbar('Distance cannot exceed 2000 km per trip.');
      return;
    }

    setState(() {
      _transportEntries.add(
        TransportEntry(mode: _transportMode, distanceKm: dist),
      );
      _distanceCtrl.clear();
    });
    _showSnackbar('Trip added successfully!', isError: false);
  }

  void _addMeal() {
    final foodName = _foodNameCtrl.text.trim();
    final gramsText = _foodGramsCtrl.text.trim();

    if (foodName.isEmpty && gramsText.isEmpty) {
      _showSnackbar('Please enter a food name and serving amount in grams.');
      return;
    }
    if (foodName.isEmpty) {
      _showSnackbar('Please enter or select a food name.');
      return;
    }
    if (gramsText.isEmpty) {
      _showSnackbar('Please enter the serving amount in grams.');
      return;
    }
    final grams = double.tryParse(gramsText);
    if (grams == null) {
      _showSnackbar(
        'Invalid amount format. Please enter a valid number of grams.',
      );
      return;
    }
    if (grams <= 0) {
      _showSnackbar('Serving amount must be greater than 0 grams.');
      return;
    }
    if (grams > 5000) {
      _showSnackbar('Serving amount cannot exceed 5000 grams.');
      return;
    }

    setState(() {
      _foodEntries.add(
        FoodEntry(
          mealSlot: _mealSlot,
          foodName: foodName,
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
    _showSnackbar('Meal added successfully!', isError: false);
  }

  void _submitLog() async {
    // Validate empty or unsubmitted fields
    if (_distanceCtrl.text.trim().isNotEmpty) {
      _showSnackbar(
        "You entered a distance of ${_distanceCtrl.text} km but haven't tapped 'Add Trip'. Tap 'Add Trip' to include it.",
      );
      return;
    }

    if (_foodNameCtrl.text.trim().isNotEmpty) {
      _showSnackbar(
        "You entered meal '${_foodNameCtrl.text}' but haven't tapped 'Add Meal'. Tap 'Add Meal' to include it.",
      );
      return;
    }

    if (_transportEntries.isEmpty &&
        _foodEntries.isEmpty &&
        !_energyConfirmed) {
      _showSnackbar(
        'Please log at least one trip or meal, or confirm energy usage before saving.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).user;
      if (user == null) {
        _showSnackbar('User session expired. Please log in again.');
        return;
      }
      final profile = await ref
          .read(userRepositoryProvider)
          .getUserProfile(user.id);

      if (profile == null) {
        _showSnackbar('Failed to fetch user profile. Please try again.');
        return;
      }

      final date = DateTime.now().toIso8601String().substring(0, 10);

      final log = CO2Calculator.processDailyLog(
        profile,
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

      // Fetch the latest log metadata from DB to determine previous log date and time
      final latestLogResponse = await Supabase.instance.client
          .from('daily_logs')
          .select('created_at, date')
          .eq('user_id', user.id)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      DateTime? lastLogTime;
      String? lastLogDateString;
      if (latestLogResponse != null) {
        final lastLogTimeStr = latestLogResponse['created_at'] as String?;
        if (lastLogTimeStr != null) {
          lastLogTime = DateTime.parse(lastLogTimeStr);
        }
        lastLogDateString = latestLogResponse['date'] as String?;
      }

      final now = DateTime.now();
      final newStreak = GamificationEngine.calculateNewStreak(
        currentStreak: profile.currentStreak,
        lastLogTime: lastLogTime,
        now: now,
        lastLogDateString: lastLogDateString,
        todayDateString: date,
      );

      int daysActive = profile.daysActive;
      if (profile.createdAt != null) {
        final signupDateTime = DateTime.parse(profile.createdAt!);
        final signupDate = DateTime(
          signupDateTime.year,
          signupDateTime.month,
          signupDateTime.day,
        );
        final todayDate = DateTime(now.year, now.month, now.day);
        daysActive = todayDate.difference(signupDate).inDays + 1;
        if (daysActive < 1) daysActive = 1;
      }

      final newXp = profile.xp + xpDelta;
      final newLevel = GamificationEngine.getLevelFromXp(newXp);

      final updatedProfile = profile.copyWith(
        xp: newXp,
        level: newLevel,
        currentStreak: newStreak,
        longestStreak: newStreak > profile.longestStreak
            ? newStreak
            : profile.longestStreak,
        daysActive: daysActive,
        totalCo2Saved: profile.totalCo2Saved + savedDelta,
      );
      await ref.read(userRepositoryProvider).saveUserProfile(updatedProfile);

      if (mounted && context.mounted) {
        ref.invalidate(recentLogsProvider(user.id));
        ref.invalidate(userProfileProvider(user.id));

        Navigator.pop(context);

        if (newLevel > profile.level) {
          final rootContext = rootNavigatorKey.currentContext;
          if (rootContext != null) {
            CelebrationModal.showLevelUp(
              rootContext,
              newLevel,
              GamificationEngine.getLevelTitle(newLevel),
            );
          }
        } else {
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
      }
    } catch (e) {
      _showSnackbar('Error saving log: $e');
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
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: _addTransportTrip,
          ),
          const SizedBox(height: 24),
          const Text(
            'Today\'s Trips:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (_transportEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No trips added yet.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
            )
          else
            ..._transportEntries.asMap().entries.map(
              (entry) => ListTile(
                title: Text(
                  entry.value.mode.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.value.distanceKm} km',
                      style: const TextStyle(color: AppColors.primaryGreen),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _transportEntries.removeAt(entry.key);
                        });
                        _showSnackbar('Trip removed', isError: false);
                      },
                    ),
                  ],
                ),
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
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Food Name (Search)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (_foodNameCtrl.text != val) {
                        _selectedFoodProduct = null;
                      }
                      _foodNameCtrl.text = val;
                    },
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
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Amount (grams)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Meal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: _addMeal,
          ),
          const SizedBox(height: 24),
          const Text(
            'Today\'s Meals:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (_foodEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No meals added yet.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
            )
          else
            ..._foodEntries.asMap().entries.map(
              (entry) => ListTile(
                title: Text(
                  '${entry.value.mealSlot}: ${entry.value.foodName}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  entry.value.category,
                  style: const TextStyle(color: AppColors.textSecondaryDark),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.value.grams}g',
                      style: const TextStyle(color: AppColors.primaryGreen),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _foodEntries.removeAt(entry.key);
                        });
                        _showSnackbar('Meal removed', isError: false);
                      },
                    ),
                  ],
                ),
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
            title: const Text(
              'Confirm Energy Usage for Today',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Required to complete full daily log',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            value: _energyConfirmed,
            activeTrackColor: AppColors.primaryGreen,
            onChanged: (v) => setState(() => _energyConfirmed = v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Any special deviations today?',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: devOptions.map((opt) {
              final isSelected = _energyDeviations.contains(opt);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: CheckboxListTile(
                  title: Text(
                    opt.replaceAll('_', ' '),
                    style: const TextStyle(color: Colors.white),
                  ),
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
