import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
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
import 'package:neutrawise/data/repositories/gamification_repository.dart';
import 'package:neutrawise/widgets/modals/error_popup.dart';

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

  // Temp form states - Travel
  String _transportMode = 'car';
  final _distanceCtrl = TextEditingController();

  // Temp form states - Food
  String _mealSlot = 'Lunch';
  final _foodNameCtrl = TextEditingController();
  String _foodCategory = 'vegetables_avg';
  String _servingSize = 'medium';
  final _foodGramsCtrl = TextEditingController(text: '250');
  OpenFoodFactsProduct? _selectedFoodProduct;

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

  // --- Helper Calculations for Preview ---

  double _getTransportLegCo2(
    String mode,
    double distanceKm,
    UserProfile? profile,
  ) {
    double factor = 0.0;
    if (mode == 'car' || mode == 'ev' || mode == 'motorcycle') {
      factor = profile?.transportFactor ?? 0.23;
    } else {
      factor = EmissionFactors.baseTransportFactors[mode] ?? 0.0;
    }
    return factor * distanceKm;
  }

  double _getFoodItemCo2(String category, double grams, double? co2Per100g) {
    return EmissionFactors.calculateFoodCo2(
      grams: grams,
      category: category,
      co2Factor: co2Per100g,
    );
  }

  double _getEnergyCo2(UserProfile? profile) {
    if (!_energyConfirmed || profile == null) return 0.0;
    double deltaKwh = 0.0;
    for (var deviation in _energyDeviations) {
      if (deviation == 'more_than_usual') {
        deltaKwh += 2.0;
      } else if (deviation == 'less_than_usual') {
        deltaKwh -= 2.0;
      } else if (deviation == 'no_ac') {
        deltaKwh -= 5.0;
      } else if (deviation == 'cold_showers') {
        deltaKwh -= 1.5;
      } else if (deviation == 'unplugged_devices') {
        deltaKwh -= 0.5;
      } else if (deviation == 'solar_panels_sunny') {
        deltaKwh -= 4.0;
      } else if (deviation == 'solar_panels_cloudy') {
        deltaKwh -= 1.5;
      }
    }

    final dailyBaselineKwh = profile.dailyEnergyBaselineKwh ?? 0.0;
    double totalKwh = dailyBaselineKwh + deltaKwh;
    if (totalKwh < 0) totalKwh = 0.0;

    final gridIntensity =
        profile.gridIntensity ?? EmissionFactors.gridIntensityPK;
    final electricityCO2 = totalKwh * gridIntensity;

    return electricityCO2 + (profile.dailyHeatingBaselineCo2 ?? 0.0);
  }

  // --- Add Handlers ---

  void _addTransportTrip(UserProfile? profile) {
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
    if (dist <= 0 || dist > 1000) {
      _showSnackbar('Distance must be positive and between 0 and 1000 km.');
      return;
    }

    final calculatedCo2 = _getTransportLegCo2(_transportMode, dist, profile);

    setState(() {
      _transportEntries.add(
        TransportEntry(
          mode: _transportMode,
          distanceKm: dist,
          calculatedCo2: calculatedCo2,
        ),
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
    if (grams <= 0 || grams > 5000) {
      _showSnackbar('Serving amount must be positive and up to 5000 grams.');
      return;
    }

    final co2Factor =
        _selectedFoodProduct?.co2Per100g ?? _selectedFoodProduct?.co2Total;
    final calculatedCo2 = _getFoodItemCo2(_foodCategory, grams, co2Factor);

    setState(() {
      _foodEntries.add(
        FoodEntry(
          mealSlot: _mealSlot,
          foodName: foodName,
          category: _foodCategory,
          servingSize: _servingSize,
          grams: grams,
          co2Per100g: co2Factor,
          calculatedCo2: calculatedCo2,
          offBarcode: _selectedFoodProduct?.id,
        ),
      );
      _foodNameCtrl.clear();
      _selectedFoodProduct = null;
    });
    _showSnackbar('Meal added successfully!', isError: false);
  }

  void _onServingSizeChanged(String size) {
    setState(() {
      _servingSize = size;
      if (size == 'small') {
        _foodGramsCtrl.text = '150';
      } else if (size == 'medium') {
        _foodGramsCtrl.text = '250';
      } else if (size == 'large') {
        _foodGramsCtrl.text = '400';
      }
    });
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

      final savedDelta =
          log.co2SavedVsBaseline -
          (widget.existingLog?.co2SavedVsBaseline ?? 0.0);
      final isFullLog =
          _transportEntries.isNotEmpty &&
          _foodEntries.isNotEmpty &&
          _energyConfirmed;

      // XP, streak, streak milestones, freeze handling and CO2-saved totals
      // are applied atomically on the server. The server uses its own date,
      // pays each milestone once, and replaces (not adds to) the XP for this
      // date when a log is re-saved.
      Map<String, dynamic>? rewards;
      try {
        rewards = await ref
            .read(userRepositoryProvider)
            .submitLogRewards(
              date: date,
              isFullLog: isFullLog,
              logXp: log.xpEarned,
              co2SavedDelta: savedDelta,
            );
      } catch (e) {
        // The log itself is already saved (and queued when offline). Rewards
        // are queued too and applied as soon as the connection is back.
        debugPrint('Could not apply log rewards: $e');
        await ref
            .read(syncManagerProvider)
            .queueRewards(
              userId: user.id,
              date: date,
              isFullLog: isFullLog,
              logXp: log.xpEarned,
              co2SavedDelta: savedDelta,
            );
      }
      final bool rewardsApplied = rewards != null;

      final int newLevel =
          (rewards?['level'] as num?)?.toInt() ?? profile.level;
      final int newStreakDays =
          (rewards?['current_streak'] as num?)?.toInt() ??
          profile.effectiveStreak;
      final bool freezeUsed = rewards?['freeze_used'] as bool? ?? false;
      final bool streakIncreased =
          rewards?['streak_increased'] as bool? ?? false;
      final isFirstLog = profile.lastLogDate == null;

      // Badges (idempotent). Milestone XP was already paid by the server.
      final gamificationRepo = ref.read(gamificationRepositoryProvider);
      if (rewardsApplied && (streakIncreased || isFirstLog || newLevel >= 10)) {
        await gamificationRepo.processStreakMilestonesAndBadges(
          userId: user.id,
          streakDays: streakIncreased ? newStreakDays : 0,
          level: newLevel,
          isFirstLog: isFirstLog,
        );
      }
      if (freezeUsed) {
        await gamificationRepo.awardBadge(
          user.id,
          'Streak Saver 🛡️',
          'Special',
          'Special',
        );
      }

      // Settle any fully-elapsed challenge days first, then record today's
      // qualification flags.
      final completedChallenges = await gamificationRepo.auditPendingChallenges(
        user.id,
      );
      await gamificationRepo.evaluateChallengesForUser(user.id, log);

      if (mounted && context.mounted) {
        ref.invalidate(recentLogsProvider(user.id));
        ref.invalidate(userProfileProvider(user.id));
        ref.invalidate(activeChallengesProvider(user.id));
        ref.invalidate(userBadgesProvider(user.id));

        Navigator.pop(context);

        final rootContext = rootNavigatorKey.currentContext;
        if (completedChallenges.isNotEmpty && rootContext != null) {
          for (final c in completedChallenges) {
            CelebrationModal.showChallengeComplete(
              rootContext,
              c['name'] as String? ?? 'Eco Challenge',
              c['xp_earned'] as int? ?? 100,
            );
          }
        } else if (newLevel > profile.level && rootContext != null) {
          CelebrationModal.showLevelUp(
            rootContext,
            newLevel,
            GamificationEngine.getLevelTitle(newLevel),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                rewardsApplied
                    ? 'Log saved! +${log.xpEarned} XP'
                    : 'Log saved. XP and streak will update when you are back online.',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorPopup.showFromException(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final profileAsync = user != null
        ? ref.watch(userProfileProvider(user.id))
        : null;
    final profile = profileAsync?.value;

    final travelCo2Sum = _transportEntries.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          (item.calculatedCo2 ??
              _getTransportLegCo2(item.mode, item.distanceKm, profile)),
    );
    final foodCo2Sum = _foodEntries.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          (item.calculatedCo2 ??
              _getFoodItemCo2(item.category, item.grams, item.co2Per100g)),
    );
    final energyCo2Sum = _getEnergyCo2(profile);
    final totalLogCo2 = travelCo2Sum + foodCo2Sum + energyCo2Sum;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log Today\'s Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.directions_car), text: 'Travel'),
                Tab(icon: Icon(Icons.restaurant), text: 'Food'),
                Tab(icon: Icon(Icons.bolt), text: 'Energy'),
              ],
              indicatorColor: AppColors.primaryGreen,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.textSecondary(context),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTransportTab(profile),
                  _buildFoodTab(),
                  _buildEnergyTab(profile),
                ],
              ),
            ),
            // Estimated Impact Summary Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppColors.surface(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Estimated CO₂:',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${totalLogCo2.toStringAsFixed(2)} kg CO₂e',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (profile?.totalDailyBaselineCo2 != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Daily Baseline:',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${profile!.totalDailyBaselineCo2!.toStringAsFixed(2)} kg CO₂e',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
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

  // --- Travel Tab ---

  Widget _buildTransportTab(UserProfile? profile) {
    final distVal = double.tryParse(_distanceCtrl.text.trim()) ?? 0.0;
    final liveTripCo2 = distVal > 0 && distVal <= 1000
        ? _getTransportLegCo2(_transportMode, distVal, profile)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _transportMode,
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.textPrimary(context)),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: const InputDecoration(
              labelText: 'Distance (0 - 1000 km)',
              border: OutlineInputBorder(),
              suffixText: 'km',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (distVal > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.co2,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trip CO₂ Preview: ${liveTripCo2.toStringAsFixed(2)} kg CO₂e',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () => _addTransportTrip(profile),
          ),
          const SizedBox(height: 24),
          Text(
            'Today\'s Logged Trips:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_transportEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No trips added yet for today.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
            )
          else
            ..._transportEntries.asMap().entries.map((entry) {
              final legCo2 =
                  entry.value.calculatedCo2 ??
                  _getTransportLegCo2(
                    entry.value.mode,
                    entry.value.distanceKm,
                    profile,
                  );
              return Card(
                color: AppColors.surface(context),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    entry.value.mode.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.value.distanceKm} km',
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${legCo2.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
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
              );
            }),
        ],
      ),
    );
  }

  // --- Food Tab ---

  Widget _buildFoodTab() {
    final gramsVal = double.tryParse(_foodGramsCtrl.text.trim()) ?? 0.0;
    final co2Factor =
        _selectedFoodProduct?.co2Per100g ?? _selectedFoodProduct?.co2Total;
    final liveMealCo2 = gramsVal > 0
        ? _getFoodItemCo2(_foodCategory, gramsVal, co2Factor)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mealSlot,
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: const InputDecoration(
              labelText: 'Meal Slot',
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
                final normalized = EmissionFactors.normalizeCategory(
                  selection.fallbackCategory,
                );
                setState(() => _foodCategory = normalized);
              }
              if (selection.servingSizeG != null &&
                  selection.servingSizeG! > 0) {
                _foodGramsCtrl.text = selection.servingSizeG!
                    .toInt()
                    .toString();
              }
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Food Search (Pakistani Dishes & OFF)',
                      helperText: 'Includes data from Open Food Facts (ODbL)',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    onChanged: (val) {
                      if (_foodNameCtrl.text != val) {
                        _selectedFoodProduct = null;
                      }
                      _foodNameCtrl.text = val;
                      setState(() {});
                    },
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  color: AppColors.surface(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 320,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        final title =
                            option.nameUrdu != null &&
                                option.nameUrdu!.isNotEmpty
                            ? '${option.name} (${option.nameUrdu})'
                            : option.name;
                        return ListTile(
                          title: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${option.brand ?? 'Traditional Pakistani'} · ${option.fallbackCategory?.replaceAll('_', ' ') ?? ''}',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                          trailing: option.ecoScore != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Score ${option.ecoScore!.toUpperCase()}',
                                    style: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _servingSize,
                  dropdownColor: AppColors.surface(context),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: const InputDecoration(
                    labelText: 'Serving Size',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'small',
                      child: Text('Small (~150g)'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium (~250g)'),
                    ),
                    DropdownMenuItem(
                      value: 'large',
                      child: Text('Large (~400g)'),
                    ),
                  ],
                  onChanged: (v) => _onServingSizeChanged(v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _foodGramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: const InputDecoration(
                    labelText: 'Amount (grams)',
                    border: OutlineInputBorder(),
                    suffixText: 'g',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'food_cat_${EmissionFactors.foodCategoryFactors.containsKey(_foodCategory) ? _foodCategory : EmissionFactors.normalizeCategory(_foodCategory)}',
            ),
            initialValue:
                EmissionFactors.foodCategoryFactors.containsKey(_foodCategory)
                ? _foodCategory
                : EmissionFactors.normalizeCategory(_foodCategory),
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: const InputDecoration(
              labelText: 'Fallback Food Category',
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
            onChanged: (v) {
              if (v != null) {
                setState(() => _foodCategory = v);
              }
            },
          ),
          if (gramsVal > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.co2,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meal CO₂ Preview: ${liveMealCo2.toStringAsFixed(2)} kg CO₂e',
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (_selectedFoodProduct != null && co2Factor != null)
                          Text(
                            'Using ${_selectedFoodProduct!.source} (${co2Factor > 50 ? (co2Factor / 100).toStringAsFixed(2) : co2Factor.toStringAsFixed(2)} kg CO₂e/kg)',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Meal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: _addMeal,
          ),
          const SizedBox(height: 24),
          Text(
            'Today\'s Logged Meals:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_foodEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No meals added yet for today.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
            )
          else
            ..._foodEntries.asMap().entries.map((entry) {
              final mealCo2 =
                  entry.value.calculatedCo2 ??
                  _getFoodItemCo2(
                    entry.value.category,
                    entry.value.grams,
                    entry.value.co2Per100g,
                  );
              return Card(
                color: AppColors.surface(context),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${entry.value.mealSlot}: ${entry.value.foodName}',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.value.category.replaceAll('_', ' ')} (${entry.value.grams}g)',
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${mealCo2.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
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
              );
            }),
        ],
      ),
    );
  }

  // --- Energy Tab ---

  Widget _buildEnergyTab(UserProfile? profile) {
    final hasSolar = profile?.hasSolar ?? false;

    // Available chips map label -> code
    final Map<String, String> chipOptions = {
      'Typical Day': 'typical_day',
      'More Than Usual': 'more_than_usual',
      'Less Than Usual': 'less_than_usual',
      'No AC': 'no_ac',
      'Cold Showers': 'cold_showers',
      'Unplugged Devices': 'unplugged_devices',
      if (!hasSolar) 'Solar Panels (Sunny)': 'solar_panels_sunny',
      if (!hasSolar) 'Solar Panels (Cloudy)': 'solar_panels_cloudy',
    };

    final liveEnergyCo2 = _getEnergyCo2(profile);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text(
              'Confirm Energy Usage for Today',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Required to include daily energy baseline & deviations in log',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
            value: _energyConfirmed,
            activeTrackColor: AppColors.primaryGreen,
            activeThumbColor: Colors.white,
            onChanged: (v) => setState(() => _energyConfirmed = v),
          ),
          Divider(color: AppColors.divider(context), height: 24),
          Text(
            'How was your energy use today?',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select any deviations from your normal household usage:',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chipOptions.entries.map((entry) {
              final label = entry.key;
              final code = entry.value;

              final isTypical = code == 'typical_day';
              final isSelected = isTypical
                  ? _energyDeviations.isEmpty
                  : _energyDeviations.contains(code);

              return FilterChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppColors.primaryGreen,
                checkmarkColor: Colors.white,
                backgroundColor: AppColors.surface(context),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (bool selected) {
                  setState(() {
                    if (isTypical) {
                      _energyDeviations.clear();
                    } else {
                      if (selected) {
                        _energyDeviations.add(code);
                      } else {
                        _energyDeviations.remove(code);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.primaryGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Energy Breakdown Today',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                    Text(
                      _energyConfirmed ? 'CONFIRMED' : 'UNCONFIRMED',
                      style: TextStyle(
                        color: _energyConfirmed
                            ? AppColors.primaryGreen
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Baseline kWh:',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                    Text(
                      '${(profile?.dailyEnergyBaselineKwh ?? 0.0).toStringAsFixed(1)} kWh/day',
                      style: TextStyle(color: AppColors.textPrimary(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Deviations:',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                    Text(
                      _energyDeviations.isEmpty
                          ? 'None (Typical)'
                          : '${_energyDeviations.length} selected',
                      style: TextStyle(color: AppColors.textPrimary(context)),
                    ),
                  ],
                ),
                Divider(color: AppColors.divider(context), height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimated Energy CO₂:',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${liveEnergyCo2.toStringAsFixed(2)} kg CO₂e',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
