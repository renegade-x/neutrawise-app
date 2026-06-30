import 'dart:math';

class GamificationEngine {
  // Level XP Thresholds (Cumulative)
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

  /// Calculate XP earned for a daily log
  static int calculateXp({
    required bool isFullLog,
    required int currentStreak,
    required int currentLevel,
    required double co2SavedPercent,
    int dailyXpCap = 500,
  }) {
    // Base XP
    final baseXp = isFullLog ? 50 : 20;

    // Performance bonus
    final performanceBonus = _calculatePerformanceBonus(co2SavedPercent);

    // Final XP = (Base XP + Bonus XP) * Streak Multiplier * Level Multiplier
    final streakMultiplier = getStreakMultiplier(currentStreak);
    final levelMultiplier = getLevelMultiplier(currentLevel);

    final rawXp =
        (baseXp + performanceBonus) * streakMultiplier * levelMultiplier;
    return min(rawXp.round(), dailyXpCap);
  }

  static double getStreakMultiplier(int streakDays) {
    if (streakDays < 7) {
      return 1.0;
    }
    if (streakDays < 30) {
      return 1.25;
    }
    return 1.5;
  }

  static double getLevelMultiplier(int level) {
    if (level < 5) {
      return 1.0;
    }
    if (level < 9) {
      return 1.1;
    }
    return 1.2;
  }

  static int _calculatePerformanceBonus(double co2SavedPercent) {
    if (co2SavedPercent >= 30) {
      return 25;
    }
    if (co2SavedPercent >= 15) {
      return 15;
    }
    if (co2SavedPercent >= 5) {
      return 8;
    }
    return 0;
  }

  /// Determine user's level from total XP
  static int getLevelFromXp(int totalXp) {
    for (int i = xpThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= xpThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  /// Get XP required to reach the next level
  static int getXpToNextLevel(int currentLevel, int currentXp) {
    if (currentLevel >= xpThresholds.length) {
      return 0; // Max level reached
    }
    final nextLevelXp = xpThresholds[currentLevel];
    return max(0, nextLevelXp - currentXp);
  }

  /// Get Level Title
  static String getLevelTitle(int level) {
    if (level < 1) return levelTitles.first;
    if (level > levelTitles.length) return levelTitles.last;
    return levelTitles[level - 1];
  }

  /// Get Level Unlocks
  static String getLevelUnlocks(int level) {
    switch (level) {
      case 1:
        return 'Basic daily log, 1 active challenge slot';
      case 2:
        return 'Activity log history, streak tracker';
      case 3:
        return 'Insights screen, monthly targets';
      case 4:
        return '2 active challenge slots, global leaderboard, Streak Freeze power-up';
      case 5:
        return 'Badge showcase, quiz bonus XP';
      case 6:
        return '3 active challenge slots, hard challenges unlock';
      case 7:
        return 'Custom profile themes';
      case 8:
        return 'Friends leaderboard, challenge creation';
      case 9:
        return 'Legacy badge, 4 active challenge slots';
      case 10:
        return 'Champion badge, permanent leaderboard star';
      default:
        return '';
    }
  }

  /// Streak update logic
  static int updateStreak({
    required int currentStreak,
    required DateTime lastLogDate,
    required DateTime todayDate,
    required bool loggedToday,
  }) {
    // Calculate difference in calendar days (ignoring time)
    final lastLogCalendarDay = DateTime(
      lastLogDate.year,
      lastLogDate.month,
      lastLogDate.day,
    );
    final todayCalendarDay = DateTime(
      todayDate.year,
      todayDate.month,
      todayDate.day,
    );
    final daysSinceLastLog = todayCalendarDay
        .difference(lastLogCalendarDay)
        .inDays;

    if (loggedToday) {
      if (daysSinceLastLog == 0) {
        return currentStreak; // Already updated today
      } else if (daysSinceLastLog == 1) {
        return currentStreak + 1; // Consecutive day
      } else {
        return 1; // Reset to 1 after a gap
      }
    } else {
      return currentStreak; // No log submitted yet
    }
  }

  /// New streak calculation following the 5 consecutive days requirement
  static int calculateNewStreak({
    required int currentStreak,
    required DateTime? lastLogTime,
    required DateTime now,
    required String? lastLogDateString,
    required String todayDateString,
  }) {
    if (lastLogTime == null) {
      return 0; // First log ever -> streak = 0
    }

    // If they already logged today, streak does not change
    if (lastLogDateString == todayDateString) {
      return currentStreak;
    }

    final timeSinceLastLog = now.difference(lastLogTime);
    if (timeSinceLastLog.inSeconds <= 24 * 3600) {
      return currentStreak + 1; // Consecutive day -> increment
    } else {
      return 0; // Missed a day -> reset to 0
    }
  }

  static const List<Map<String, String>> badgeMetadata = [
    {
      'name': 'Road to Green',
      'desc': 'Reducing transport emissions',
      'criteria':
          'Awarded when your total transport emissions are reduced by 20% or more compared to your baseline.',
    },
    {
      'name': 'Conscious Plate',
      'desc': 'Sustainable eating habits',
      'criteria':
          'Awarded when you log at least 3 meatless/sustainable food choices in a week.',
    },
    {
      'name': 'Power Saver',
      'desc': 'Reducing home energy use',
      'criteria':
          'Awarded when your energy emissions are at least 15% below baseline for 5 consecutive days.',
    },
    {
      'name': 'Nature Keeper',
      'desc': 'Active nature preservation',
      'criteria':
          'Awarded when you complete at least 2 nature preservation challenges.',
    },
    {
      'name': 'Mindful Consumer',
      'desc': 'Sustainable living choices',
      'criteria':
          'Awarded when you log at least 5 sustainable lifestyle/consumer choices.',
    },
    {
      'name': 'Week Warrior 🔥',
      'desc': '7-day streak milestone',
      'criteria':
          'Awarded for logging your carbon footprint for 7 consecutive days.',
    },
    {
      'name': 'Monthly Maven 🌿',
      'desc': '30-day streak milestone',
      'criteria':
          'Awarded for logging your carbon footprint for 30 consecutive days.',
    },
    {
      'name': 'Century Eco 🏆',
      'desc': '100-day streak milestone',
      'criteria':
          'Awarded for logging your carbon footprint for 100 consecutive days.',
    },
    {
      'name': 'Eco Newcomer ✨',
      'desc': 'First activity log',
      'criteria': 'Awarded when you log your first activity in the app.',
    },
    {
      'name': 'All-Rounder 🌐',
      'desc': '1 challenge in all categories',
      'criteria':
          'Awarded when you complete at least one challenge in all available categories.',
    },
    {
      'name': 'Carbon Neutral 🌍',
      'desc': 'Reach Level 10',
      'criteria':
          'Awarded when you reach Level 10 of your carbon neutrality journey.',
    },
  ];
}
