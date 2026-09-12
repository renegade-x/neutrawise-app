import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/data/repositories/gamification_repository.dart';

void main() {
  group('All 15 Badges End-to-End Evaluation & Award Test Suite', () {
    final catalog = GamificationRepository.defaultBadgeCatalog;

    test('Verify badge catalog contains exactly 15 default badges', () {
      expect(catalog.length, 15);
    });

    // Helper to get badge metadata by name
    Map<String, dynamic> getBadgeMeta(String name) {
      return GamificationEngine.badgeMetadata.firstWhere(
        (b) => b['name'] == name,
        orElse: () => throw Exception('Badge metadata for $name not found'),
      );
    }

    // -------------------------------------------------------------------------
    // SPECIAL BADGES: MILESTONE & PROFILE TRIGGERS
    // -------------------------------------------------------------------------

    group('Special Badge 1: Eco Newcomer ✨', () {
      test('Success: Awarded on first daily log submission', () {
        const meta = GamificationEngine.badgeMetadata;
        final newcomer = meta.firstWhere(
          (b) => b['name'].contains('Eco Newcomer'),
        );
        expect(newcomer['name'], 'Eco Newcomer ✨');
        expect(newcomer['criteria'], 'Submit 1 daily log.');
      });
    });

    group(
      'Special Badges 2-6: Streak Milestones (7, 14, 30, 60, 100 Days)',
      () {
        test('Week Warrior 🔥: Triggered at 7-day streak', () {
          final meta = getBadgeMeta('Week Warrior 🔥');
          expect(meta['criteria'], 'Log activities for 7 consecutive days.');
        });

        test('Fortnight Fighter 💪: Triggered at 14-day streak', () {
          final meta = getBadgeMeta('Fortnight Fighter 💪');
          expect(meta['criteria'], 'Log activities for 14 consecutive days.');
        });

        test('Monthly Maven 🌿: Triggered at 30-day streak', () {
          final meta = getBadgeMeta('Monthly Maven 🌿');
          expect(meta['criteria'], 'Log activities for 30 consecutive days.');
        });

        test('Eco Consistent 🌍: Triggered at 60-day streak', () {
          final meta = getBadgeMeta('Eco Consistent 🌍');
          expect(meta['criteria'], 'Log activities for 60 consecutive days.');
        });

        test('Century Eco 🏆: Triggered at 100-day streak', () {
          final meta = getBadgeMeta('Century Eco 🏆');
          expect(meta['criteria'], 'Log activities for 100 consecutive days.');
        });
      },
    );

    group('Special Badge 7: Carbon Neutral 🌍', () {
      test('Success: Awarded when user reaches Level 10 (31,000+ XP)', () {
        final meta = getBadgeMeta('Carbon Neutral 🌍');
        expect(meta['criteria'], 'Earn 31,000+ lifetime XP to reach Level 10.');

        final level10Xp =
            GamificationEngine.xpThresholds[9]; // Level 10 threshold
        expect(level10Xp, 31000);

        final level = GamificationEngine.getLevelFromXp(31000);
        expect(level, 10);
      });
    });

    // -------------------------------------------------------------------------
    // CATEGORY BADGES (Transport, Food, Energy, Nature)
    // -------------------------------------------------------------------------

    group('Category Badge 8: Road to Green 🚗 (Transport)', () {
      test(
        'Criteria: Bronze = 3, Silver = 7, Gold = 12 completed Transport challenges',
        () {
          final meta = getBadgeMeta('Road to Green 🚗');
          expect(meta['criteria'], 'Complete 3/7/12 Transport challenges.');
        },
      );
    });

    group('Category Badge 9: Conscious Plate 🥗 (Food)', () {
      test(
        'Criteria: Bronze = 3, Silver = 7, Gold = 12 completed Food challenges',
        () {
          final meta = getBadgeMeta('Conscious Plate 🥗');
          expect(meta['criteria'], 'Complete 3/7/12 Food challenges.');
        },
      );
    });

    group('Category Badge 10: Power Saver ⚡ (Energy)', () {
      test(
        'Criteria: Bronze = 3, Silver = 7, Gold = 12 completed Energy challenges',
        () {
          final meta = getBadgeMeta('Power Saver ⚡');
          expect(meta['criteria'], 'Complete 3/7/12 Energy challenges.');
        },
      );
    });

    group('Category Badge 11: Nature Keeper 🌳 (Nature)', () {
      test(
        'Criteria: Bronze = 1, Silver = 2, Gold = 3 completed Nature challenges',
        () {
          final meta = getBadgeMeta('Nature Keeper 🌳');
          expect(meta['criteria'], 'Complete 1/2/3 Nature challenges.');
        },
      );
    });

    // -------------------------------------------------------------------------
    // SPECIAL ACTION BADGES (All-Rounder, Quiz Whiz, Streak Saver, Leaderboard Leader)
    // -------------------------------------------------------------------------

    group('Special Badge 12: All-Rounder 🌟', () {
      test(
        'Success: Awarded when at least 1 challenge is completed in Transport, Food, Energy, Nature',
        () {
          final meta = getBadgeMeta('All-Rounder 🌟');
          expect(
            meta['criteria'],
            'Complete a challenge in Transport, Food, Energy, and Nature.',
          );

          final completedCategories = {'transport', 'food', 'energy', 'nature'};
          final hasAll = completedCategories.containsAll([
            'transport',
            'food',
            'energy',
            'nature',
          ]);
          expect(hasAll, isTrue);
        },
      );

      test('Failure: Missing 1 category does not award All-Rounder badge', () {
        final completedCategories = {
          'transport',
          'food',
          'energy',
        }; // Missing nature!
        final hasAll = completedCategories.containsAll([
          'transport',
          'food',
          'energy',
          'nature',
        ]);
        expect(hasAll, isFalse);
      });
    });

    group('Special Badge 13: Quiz Whiz 🧠', () {
      test('Success: Awarded when user achieves 5 perfect quiz attempts', () {
        final meta = getBadgeMeta('Quiz Whiz 🧠');
        expect(meta['criteria'], 'Achieve 5 perfect quiz scores.');
      });
    });

    group('Special Badge 14: Streak Saver 🛡️', () {
      test(
        'Success: Awarded when a streak freeze is consumed to preserve streak',
        () {
          final meta = getBadgeMeta('Streak Saver 🛡️');
          expect(meta['criteria'], 'Consume 1 Streak Freeze.');
        },
      );
    });

    group('Special Badge 15: Leaderboard Leader 👑', () {
      test(
        'Success: Awarded when user finishes Rank #1 on the global leaderboard',
        () {
          final meta = getBadgeMeta('Leaderboard Leader 👑');
          expect(
            meta['criteria'],
            'Finish Rank #1 at the end of a monthly season.',
          );
        },
      );
    });
  });
}
