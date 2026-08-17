import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/widgets/user_avatar.dart';

void main() {
  group('UserAvatar Widget Tests', () {
    testWidgets('renders initials when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UserAvatar(name: 'Jane Doe')),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('renders single initial for single word name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UserAvatar(name: 'Alex')),
        ),
      );

      expect(find.text('AL'), findsOneWidget);
    });

    testWidgets('renders emoji when avatarUrl starts with emoji:', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(name: 'Eco Warrior', avatarUrl: 'emoji:🌿'),
          ),
        ),
      );

      expect(find.text('🌿'), findsOneWidget);
    });

    testWidgets('renders camera badge when showEditBadge is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(name: 'Jane Doe', showEditBadge: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('triggers onTap callback when clicked', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              name: 'Jane Doe',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(UserAvatar));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
