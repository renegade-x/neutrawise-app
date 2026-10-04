import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/domain/models/user_profile.dart';

void main() {
  group('editableProfileJson', () {
    const profile = UserProfile(
      id: 'u1',
      name: 'Eco User',
      city: 'Lahore',
      transportFactor: 0.23,
      xp: 900,
      lifetimeXp: 900,
      monthlyXp: 120,
      level: 2,
      currentStreak: 5,
      streakDays: 5,
      longestStreak: 9,
      fullLogStreakDays: 3,
      lastLogDate: '2026-10-03',
      streakFreezeHeld: true,
      daysActive: 12,
      totalCo2Saved: 42.5,
    );

    test('never includes server-managed XP, level or streak columns', () {
      final json = UserRepository.editableProfileJson(profile);
      for (final column in UserRepository.serverManagedColumns) {
        expect(json.containsKey(column), isFalse, reason: '$column leaked');
      }
    });

    test('keeps ordinary profile fields', () {
      final json = UserRepository.editableProfileJson(profile);
      expect(json['id'], 'u1');
      expect(json['name'], 'Eco User');
      expect(json['city'], 'Lahore');
      expect(json['transport_factor'], 0.23);
    });

    test('drops created_at when it was never set', () {
      final json = UserRepository.editableProfileJson(profile);
      expect(json.containsKey('created_at'), isFalse);
    });
  });
}
