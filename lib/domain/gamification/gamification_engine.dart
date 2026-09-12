import 'dart:math';
import 'package:neutrawise/domain/models/daily_log.dart';

class ChallengeDefinition {
  final String id;
  final String name;
  final String category; // Transport, Food, Energy, Nature
  final String difficulty; // Easy, Medium, Hard
  final String durationType; // single_day, multi_day
  final int windowDays;
  final int requiredDays;
  final bool consecutive;
  final int xpReward;
  final String strategy;
  final Map<String, dynamic> strategyParams;
  final String? startDayConstraint; // e.g. 'saturday'

  const ChallengeDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.durationType,
    required this.windowDays,
    required this.requiredDays,
    required this.consecutive,
    required this.xpReward,
    required this.strategy,
    required this.strategyParams,
    this.startDayConstraint,
  });
}

class GamificationEngine {
  // Level XP Thresholds (Cumulative) - Section 4
  static const List<int> xpThresholds = [
    0, // Level 1
    500, // Level 2
    1500, // Level 3
    3000, // Level 4
    5000, // Level 5
    8000, // Level 6
    12000, // Level 7
    17000, // Level 8
    23000, // Level 9
    31000, // Level 10
  ];

  static const List<String> levelTitles = [
    'Eco Newcomer',
    'Green Sprout',
    'Eco Explorer',
    'Sustainability Seeker',
    'Eco Advocate',
    'Climate Champion',
    'Green Guardian',
    'Eco Hero',
    'Carbon Crusader',
    'Carbon Neutral',
  ];

  // 15 Standard Challenges - Section 6.7
  static const List<ChallengeDefinition> challengeLibrary = [
    // Transport
    ChallengeDefinition(
      id: 'no_car_day',
      name: 'No Car Day',
      category: 'Transport',
      difficulty: 'Easy',
      durationType: 'single_day',
      windowDays: 1,
      requiredDays: 1,
      consecutive: false,
      xpReward: 100,
      strategy: 'LOG_FIELD_ZERO',
      strategyParams: {'field': 'car_km'},
    ),
    ChallengeDefinition(
      id: 'no_car_weekend',
      name: 'No Car Weekend',
      category: 'Transport',
      difficulty: 'Easy',
      durationType: 'multi_day',
      windowDays: 2,
      requiredDays: 2,
      consecutive: true,
      xpReward: 100,
      strategy: 'LOG_FIELD_ZERO',
      strategyParams: {'field': 'car_km'},
      startDayConstraint: 'saturday',
    ),
    ChallengeDefinition(
      id: 'walk_7_days',
      name: 'Walk 7 Days',
      category: 'Transport',
      difficulty: 'Easy',
      durationType: 'multi_day',
      windowDays: 10,
      requiredDays: 7,
      consecutive: false,
      xpReward: 100,
      strategy: 'TRANSPORT_ANY_MATCH',
      strategyParams: {
        'accepted_values': ['walking'],
      },
    ),
    ChallengeDefinition(
      id: 'cycle_to_work_week',
      name: 'Cycle to Work Week',
      category: 'Transport',
      difficulty: 'Medium',
      durationType: 'multi_day',
      windowDays: 7,
      requiredDays: 5,
      consecutive: false,
      xpReward: 200,
      strategy: 'TRANSPORT_ANY_MATCH',
      strategyParams: {
        'accepted_values': ['cycling'],
      },
    ),
    ChallengeDefinition(
      id: 'no_car_week',
      name: 'No Car Week',
      category: 'Transport',
      difficulty: 'Medium',
      durationType: 'multi_day',
      windowDays: 10,
      requiredDays: 7,
      consecutive: true,
      xpReward: 200,
      strategy: 'LOG_FIELD_ZERO',
      strategyParams: {'field': 'car_km'},
    ),
    ChallengeDefinition(
      id: 'carpool_champion',
      name: 'Carpool Champion',
      category: 'Transport',
      difficulty: 'Medium',
      durationType: 'multi_day',
      windowDays: 7,
      requiredDays: 5,
      consecutive: false,
      xpReward: 200,
      strategy: 'TRANSPORT_ANY_MATCH',
      strategyParams: {
        'accepted_values': ['rideshare'],
      },
    ),
    ChallengeDefinition(
      id: 'public_transport_month',
      name: 'Public Transport Month',
      category: 'Transport',
      difficulty: 'Hard',
      durationType: 'multi_day',
      windowDays: 35,
      requiredDays: 30,
      consecutive: true,
      xpReward: 400,
      strategy: 'TRANSPORT_ALL_MATCH',
      strategyParams: {
        'accepted_values': ['bus', 'train', 'metro', 'tram', 'ferry'],
      },
    ),
    // Food
    ChallengeDefinition(
      id: 'meat_free_day',
      name: 'Meat-Free Day',
      category: 'Food',
      difficulty: 'Easy',
      durationType: 'single_day',
      windowDays: 1,
      requiredDays: 1,
      consecutive: false,
      xpReward: 100,
      strategy: 'FOOD_NONE_MATCH',
      strategyParams: {
        'excluded_values': [
          'beef',
          'pork',
          'poultry',
          'chicken',
          'lamb',
          'fish',
          'seafood',
        ],
      },
    ),
    ChallengeDefinition(
      id: 'plant_based_week',
      name: 'Plant-Based Week',
      category: 'Food',
      difficulty: 'Medium',
      durationType: 'multi_day',
      windowDays: 9,
      requiredDays: 7,
      consecutive: true,
      xpReward: 200,
      strategy: 'FOOD_ALL_MATCH',
      strategyParams: {
        'accepted_values': [
          'vegetables',
          'legumes',
          'tofu',
          'soy',
          'fruit',
          'grains',
          'nuts',
          'seeds',
        ],
      },
    ),
    ChallengeDefinition(
      id: 'vegan_challenge',
      name: 'Vegan Challenge',
      category: 'Food',
      difficulty: 'Hard',
      durationType: 'multi_day',
      windowDays: 35,
      requiredDays: 30,
      consecutive: true,
      xpReward: 400,
      strategy: 'FOOD_ALL_MATCH',
      strategyParams: {
        'accepted_values': [
          'vegetables',
          'legumes',
          'tofu',
          'soy',
          'fruit',
          'grains',
          'nuts',
          'seeds',
        ],
      },
    ),
    // Energy
    ChallengeDefinition(
      id: 'unplug_day',
      name: 'Unplug Day',
      category: 'Energy',
      difficulty: 'Easy',
      durationType: 'single_day',
      windowDays: 1,
      requiredDays: 1,
      consecutive: false,
      xpReward: 100,
      strategy: 'LOG_TAG_PRESENT',
      strategyParams: {'tag': 'unplugged_devices'},
    ),
    ChallengeDefinition(
      id: 'cold_shower_week',
      name: 'Cold Shower Week',
      category: 'Energy',
      difficulty: 'Easy',
      durationType: 'multi_day',
      windowDays: 10,
      requiredDays: 7,
      consecutive: false,
      xpReward: 100,
      strategy: 'LOG_TAG_PRESENT',
      strategyParams: {'tag': 'cold_shower'},
    ),
    ChallengeDefinition(
      id: 'screen_time_cutback',
      name: 'Screen Time Cutback',
      category: 'Energy',
      difficulty: 'Easy',
      durationType: 'multi_day',
      windowDays: 10,
      requiredDays: 7,
      consecutive: false,
      xpReward: 100,
      strategy: 'LOG_TAG_PRESENT',
      strategyParams: {'tag': 'low_screen_time'},
    ),
    ChallengeDefinition(
      id: 'no_ac_week',
      name: 'No AC Week',
      category: 'Energy',
      difficulty: 'Medium',
      durationType: 'multi_day',
      windowDays: 7,
      requiredDays: 7,
      consecutive: true,
      xpReward: 200,
      strategy: 'LOG_TAG_ABSENT',
      strategyParams: {'tag': 'ac_used'},
    ),
    // Nature
    ChallengeDefinition(
      id: 'green_journey_100',
      name: '100-Day Green Journey',
      category: 'Nature',
      difficulty: 'Hard',
      durationType: 'multi_day',
      windowDays: 100,
      requiredDays: 100,
      consecutive: true,
      xpReward: 400,
      strategy: 'APP_BEHAVIOR',
      strategyParams: {'metric': 'consecutive_active_days'},
    ),
  ];

  // --- XP & Multiplier Calculations (Section 3) ---

  /// Helper to determine if energy section is confirmed
  static bool isEnergyConfirmed(DailyLog log) {
    return log.energyConfirmed ||
        log.energyCo2 > 0 ||
        log.energyDeviations.isNotEmpty;
  }

  /// Helper to determine if a daily log is a full log (all 3 categories confirmed)
  static bool isFullLog(DailyLog log) {
    final hasTransport =
        log.transportEntries.isNotEmpty || log.transportCo2 > 0;
    final hasFood = log.foodEntries.isNotEmpty || log.foodCo2 > 0;
    return hasTransport && hasFood && isEnergyConfirmed(log);
  }

  /// Multiplier for full log streak (Section 3.3)
  static double getStreakMultiplier(int fullLogStreakDays) {
    if (fullLogStreakDays >= 100) return 1.75;
    if (fullLogStreakDays >= 30) return 1.50;
    if (fullLogStreakDays >= 7) return 1.25;
    return 1.00;
  }

  /// Multiplier for current level (Section 3.3)
  static double getLevelMultiplier(int level) {
    if (level >= 9) return 1.20;
    if (level >= 5) return 1.10;
    return 1.00;
  }

  /// Performance bonus for CO2 reduction vs baseline (Section 3.2 & 3.3)
  /// Note: percentVsBaseline is negative when emissions are below baseline (e.g. -20% = 20% below baseline)
  static int calculatePerformanceBonus({
    required bool isFull,
    required double percentVsBaseline,
  }) {
    if (!isFull) return 0;
    // Normalize: if positive percentage of savings is passed, convert to negative
    final pctBelow = percentVsBaseline > 0
        ? -percentVsBaseline
        : percentVsBaseline;
    if (pctBelow <= -30.0) return 25;
    if (pctBelow <= -15.0) return 15;
    if (pctBelow <= -5.0) return 8;
    return 0;
  }

  /// Primary Daily XP award function (Section 12.1)
  static Map<String, dynamic> awardDailyXP({
    required DailyLog dailyResult,
    required int fullLogStreakDays,
    required int level,
    required int alreadyAwardedForDate,
  }) {
    final isFull = isFullLog(dailyResult);
    final baseXP = isFull ? 50 : 20;

    // Streak multiplier only applies if today's log is FULL
    final streakMult = isFull ? getStreakMultiplier(fullLogStreakDays) : 1.00;
    final levelMult = getLevelMultiplier(level);

    final preBonus = (baseXP * streakMult * levelMult).round();
    final perfBonus = calculatePerformanceBonus(
      isFull: isFull,
      percentVsBaseline: dailyResult.percentVsBaseline,
    );

    final newTotal = preBonus + perfBonus;
    final deltaXP = max(0, newTotal - alreadyAwardedForDate);

    return {
      'isFullLog': isFull,
      'baseXP': baseXP,
      'streakMult': streakMult,
      'levelMult': levelMult,
      'preBonus': preBonus,
      'perfBonus': perfBonus,
      'newTotal': newTotal,
      'deltaXP': deltaXP,
    };
  }

  // --- Level Progression (Section 4) ---

  static int getLevelFromXp(int lifetimeXp) {
    for (int i = xpThresholds.length - 1; i >= 0; i--) {
      if (lifetimeXp >= xpThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  static int getXpToNextLevel(int currentLevel, int lifetimeXp) {
    if (currentLevel >= xpThresholds.length) return 0;
    return max(0, xpThresholds[currentLevel] - lifetimeXp);
  }

  static String getLevelTitle(int level) {
    if (level < 1) return levelTitles.first;
    if (level > levelTitles.length) return levelTitles.last;
    return levelTitles[level - 1];
  }

  static int getChallengeSlotsForLevel(int level) {
    if (level >= 9) return 4;
    if (level >= 6) return 3;
    if (level >= 4) return 2;
    return 1;
  }

  static bool areHardChallengesUnlocked(int level) => level >= 6;
  static bool isQuizPerfectBonusUnlocked(int level) => level >= 5;
  static bool isStreakFreezeUnlocked(int level) => level >= 4;

  // --- Challenge Strategy Evaluation (Section 12.3) ---

  static bool evaluateStrategy({
    required String strategy,
    required Map<String, dynamic> params,
    required DailyLog dailyResult,
  }) {
    switch (strategy) {
      case 'LOG_FIELD_ZERO':
        final field = params['field'] as String? ?? 'car_km';
        if (field == 'car_km') {
          double totalCarKm = 0.0;
          for (var entry in dailyResult.transportEntries) {
            final mode = entry.mode.trim().toLowerCase();
            if (mode == 'car' ||
                mode == 'petrol_car' ||
                mode == 'diesel_car' ||
                mode == 'driving' ||
                mode == 'ev' ||
                mode == 'motorcycle' ||
                mode == 'taxi' ||
                mode == 'rideshare') {
              totalCarKm += entry.distanceKm;
            }
          }
          return totalCarKm == 0.0;
        }
        return true;

      case 'TRANSPORT_ANY_MATCH':
        final accepted = (params['accepted_values'] as List? ?? [])
            .map((e) => e.toString().trim().toLowerCase())
            .toSet();
        return dailyResult.transportEntries.any(
          (leg) => accepted.contains(leg.mode.trim().toLowerCase()),
        );

      case 'TRANSPORT_ALL_MATCH':
        if (dailyResult.transportEntries.isEmpty) return false;
        final accepted = (params['accepted_values'] as List? ?? [])
            .map((e) => e.toString().trim().toLowerCase())
            .toSet();
        return dailyResult.transportEntries.every(
          (leg) => accepted.contains(leg.mode.trim().toLowerCase()),
        );

      case 'FOOD_NONE_MATCH':
        if (dailyResult.foodEntries.isEmpty) return false;
        final excluded = (params['excluded_values'] as List? ?? [])
            .map((e) => e.toString().trim().toLowerCase())
            .toSet();
        return !dailyResult.foodEntries.any(
          (entry) => excluded.contains(entry.category.trim().toLowerCase()),
        );

      case 'FOOD_ALL_MATCH':
        if (dailyResult.foodEntries.isEmpty) return false;
        final accepted = (params['accepted_values'] as List? ?? [])
            .map((e) => e.toString().trim().toLowerCase())
            .toSet();
        return dailyResult.foodEntries.every(
          (entry) => accepted.contains(entry.category.trim().toLowerCase()),
        );

      case 'LOG_TAG_PRESENT':
        if (!isEnergyConfirmed(dailyResult)) return false;
        final targetTag = (params['tag'] as String? ?? '').trim().toLowerCase();
        return dailyResult.energyDeviations.any((d) {
          final dev = d.trim().toLowerCase();
          if (targetTag == dev) return true;
          if (targetTag == 'cold_shower' && dev == 'cold_showers') return true;
          if (targetTag == 'cold_showers' && dev == 'cold_shower') return true;
          return false;
        });

      case 'LOG_TAG_ABSENT':
        if (!isEnergyConfirmed(dailyResult)) return false;
        final targetTag = (params['tag'] as String? ?? '').trim().toLowerCase();
        return !dailyResult.energyDeviations.any((d) {
          final dev = d.trim().toLowerCase();
          if (targetTag == dev) return true;
          if ((targetTag == 'ac_used' || targetTag == 'ac') && dev == 'ac_used') {
            return true;
          }
          return false;
        });

      case 'APP_BEHAVIOR':
        return true;

      default:
        return false;
    }
  }

  // --- Challenge Decay & Cooldown (Section 3.6 & 6.5) ---

  static int calculateChallengeXpReward({
    required int baseXP,
    required int completionNumber,
  }) {
    if (completionNumber <= 1) return baseXP;
    final mult = max(0.50, 1.0 - 0.10 * (completionNumber - 1));
    return (baseXP * mult).round();
  }

  static int calculateDecayedXP(int baseXP, int completionNumber) =>
      calculateChallengeXpReward(
        baseXP: baseXP,
        completionNumber: completionNumber,
      );

  static int getBaseCooldownDays(String difficulty, String durationType) {
    final diff = difficulty.trim().toLowerCase();
    final type = durationType.trim().toLowerCase();

    if (diff == 'easy') {
      return type == 'single_day' ? 7 : 14;
    } else if (diff == 'medium') {
      return 30;
    } else if (diff == 'hard') {
      return 90;
    }
    return 7;
  }

  static int calculateCooldownDays({
    required String difficulty,
    required int completionNumber,
    String? durationType,
    int? durationDays,
  }) {
    final type =
        durationType ??
        ((durationDays != null && durationDays == 1)
            ? 'single_day'
            : 'multi_day');
    final base = getBaseCooldownDays(difficulty, type);
    if (completionNumber <= 1) return base;
    final mult = min(3.0, 1.0 + 0.5 * (completionNumber - 1));
    return (base * mult).round();
  }

  static bool isChallengeOnCooldown({
    required String difficulty,
    required DateTime? completedAt,
    required DateTime now,
    int? durationDays,
    int completionNumber = 1,
  }) {
    if (completedAt == null) return false;
    final durationType = (durationDays != null && durationDays == 1)
        ? 'single_day'
        : 'multi_day';
    final cdDays = calculateCooldownDays(
      difficulty: difficulty,
      durationType: durationType,
      completionNumber: completionNumber,
    );
    final cooldownEnd = completedAt.add(Duration(days: cdDays));
    return now.isBefore(cooldownEnd);
  }

  static int getRemainingCooldownDays({
    required String difficulty,
    required DateTime? completedAt,
    required DateTime now,
    int? durationDays,
    int completionNumber = 1,
  }) {
    if (completedAt == null) return 0;
    final durationType = (durationDays != null && durationDays == 1)
        ? 'single_day'
        : 'multi_day';
    final cdDays = calculateCooldownDays(
      difficulty: difficulty,
      durationType: durationType,
      completionNumber: completionNumber,
    );
    final cooldownEnd = completedAt.add(Duration(days: cdDays));
    if (now.isAfter(cooldownEnd)) return 0;
    return cooldownEnd.difference(now).inDays + 1;
  }

  static const List<Map<String, dynamic>> badgeMetadata = [
    {
      'name': 'Road to Green 🚗',
      'desc': 'Complete Transport challenges (Bronze: 3, Silver: 7, Gold: 12).',
      'criteria': 'Complete 3/7/12 Transport challenges.',
    },
    {
      'name': 'Conscious Plate 🥗',
      'desc': 'Complete Food challenges (Bronze: 3, Silver: 7, Gold: 12).',
      'criteria': 'Complete 3/7/12 Food challenges.',
    },
    {
      'name': 'Power Saver ⚡',
      'desc': 'Complete Energy challenges (Bronze: 3, Silver: 7, Gold: 12).',
      'criteria': 'Complete 3/7/12 Energy challenges.',
    },
    {
      'name': 'Nature Keeper 🌳',
      'desc': 'Complete Nature challenges (Bronze: 1, Silver: 2, Gold: 3).',
      'criteria': 'Complete 1/2/3 Nature challenges.',
    },
    {
      'name': 'Eco Newcomer ✨',
      'desc': 'Submit your first daily activity log.',
      'criteria': 'Submit 1 daily log.',
    },
    {
      'name': 'Week Warrior 🔥',
      'desc': 'Maintain a 7-day logging streak.',
      'criteria': 'Log activities for 7 consecutive days.',
    },
    {
      'name': 'Fortnight Fighter 💪',
      'desc': 'Maintain a 14-day logging streak.',
      'criteria': 'Log activities for 14 consecutive days.',
    },
    {
      'name': 'Monthly Maven 🌿',
      'desc': 'Maintain a 30-day logging streak.',
      'criteria': 'Log activities for 30 consecutive days.',
    },
    {
      'name': 'Eco Consistent 🌍',
      'desc': 'Maintain a 60-day logging streak.',
      'criteria': 'Log activities for 60 consecutive days.',
    },
    {
      'name': 'Century Eco 🏆',
      'desc': 'Maintain a 100-day logging streak.',
      'criteria': 'Log activities for 100 consecutive days.',
    },
    {
      'name': 'Quiz Whiz 🧠',
      'desc': 'Score 10/10 on 5 bi-weekly quizzes.',
      'criteria': 'Achieve 5 perfect quiz scores.',
    },
    {
      'name': 'Streak Saver 🛡️',
      'desc': 'Use a Streak Freeze to save a streak.',
      'criteria': 'Consume 1 Streak Freeze.',
    },
    {
      'name': 'All-Rounder 🌟',
      'desc': 'Complete at least 1 challenge in each active category.',
      'criteria':
          'Complete a challenge in Transport, Food, Energy, and Nature.',
    },
    {
      'name': 'Carbon Neutral 🌍',
      'desc': 'Reach Level 10 Carbon Neutral mastery.',
      'criteria': 'Earn 31,000+ lifetime XP to reach Level 10.',
    },
    {
      'name': 'Leaderboard Leader 👑',
      'desc': 'Finish Rank #1 on the monthly global leaderboard.',
      'criteria': 'Finish Rank #1 at the end of a monthly season.',
    },
  ];
}
