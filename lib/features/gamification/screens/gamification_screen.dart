import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/repositories/gamification_repository.dart';
import 'package:neutrawise/data/repositories/leaderboard_repository.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';
import 'package:neutrawise/data/repositories/quiz_repository.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
import 'package:neutrawise/widgets/user_avatar.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/widgets/animated_progress_bar.dart';
import 'package:neutrawise/widgets/celebration_modal.dart';
import 'package:neutrawise/features/gamification/widgets/quiz_modal.dart';

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _leaderboardType = 'global';

  // Standard Challenge Library
  final List<Map<String, dynamic>> _challengeLibrary = [
    {
      'id': 'no_car_day',
      'name': 'No Car Day',
      'category': 'Transport',
      'difficulty': 'Easy',
      'duration': 1,
      'xp': 100,
    },
    {
      'id': 'meatless_monday',
      'name': 'Meatless Monday',
      'category': 'Food',
      'difficulty': 'Easy',
      'duration': 1,
      'xp': 100,
    },
    {
      'id': 'cold_shower_week',
      'name': 'Cold Shower Week',
      'category': 'Energy',
      'difficulty': 'Easy',
      'duration': 7,
      'xp': 100,
    },
    {
      'id': 'secondhand_shopping',
      'name': 'Secondhand Shopping Week',
      'category': 'Lifestyle',
      'difficulty': 'Easy',
      'duration': 7,
      'xp': 100,
    },
    {
      'id': 'plant_a_tree',
      'name': 'Plant a Tree',
      'category': 'Nature',
      'difficulty': 'Medium',
      'duration': 1,
      'xp': 200,
    },
    {
      'id': 'public_transit_master',
      'name': 'Public Transit Master',
      'category': 'Transport',
      'difficulty': 'Medium',
      'duration': 7,
      'xp': 250,
    },
    {
      'id': 'zero_waste_month',
      'name': 'Zero Waste Month',
      'category': 'Lifestyle',
      'difficulty': 'Hard',
      'duration': 30,
      'xp': 500,
    },
    {
      'id': 'vegan_month',
      'name': '30-Day Vegan Challenge',
      'category': 'Food',
      'difficulty': 'Hard',
      'duration': 30,
      'xp': 500,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = ref.watch(userProfileProvider(user.id));
    final badgesAsync = ref.watch(userBadgesProvider(user.id));
    final challengesAsync = ref.watch(activeChallengesProvider(user.id));
    final userChallengesAsync = ref.watch(userChallengesProvider(user.id));
    final leaderboardAsync = ref.watch(leaderboardProvider(_leaderboardType));

    return Scaffold(
      body: Container(
        color: AppColors.backgroundDark,
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile not found'));
              }

              final int currentLevel = profile.level;
              final int currentXp = profile.xp;
              final int xpToNext = GamificationEngine.getXpToNextLevel(
                currentLevel,
                currentXp,
              );
              final String levelTitle = GamificationEngine.getLevelTitle(
                currentLevel,
              );
              final double levelProgress = _calculateLevelProgress(
                currentLevel,
                currentXp,
              );

              return Column(
                children: [
                  // Level Header Banner
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Level $currentLevel',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  levelTitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Multiplier: x${GamificationEngine.getLevelMultiplier(currentLevel).toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedProgressBar(
                          value: levelProgress,
                          backgroundColor: Colors.white10,
                          valueColor: AppColors.primaryGreen,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$currentXp XP total',
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              xpToNext > 0
                                  ? '$xpToNext XP to Level ${currentLevel + 1}'
                                  : 'Max Level Reached',
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tabs bar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryGreen,
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: AppColors.textSecondaryDark,
                    tabs: const [
                      Tab(text: 'Challenges'),
                      Tab(text: 'Badges'),
                      Tab(text: 'Leaderboard'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: Challenges
                        challengesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e')),
                          data: (challenges) => _buildChallengesTab(
                            profile.id,
                            challenges,
                            userChallengesAsync.value ?? [],
                          ),
                        ),

                        // TAB 2: Badges
                        badgesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e')),
                          data: (earnedBadges) => _buildBadgesTab(earnedBadges),
                        ),

                        // TAB 3: Leaderboard
                        leaderboardAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e')),
                          data: (leaderboard) =>
                              _buildLeaderboardTab(profile, leaderboard),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _calculateLevelProgress(int level, int xp) {
    if (level >= GamificationEngine.xpThresholds.length) return 1.0;
    final int minXp = GamificationEngine.xpThresholds[level - 1];
    final int maxXp = GamificationEngine.xpThresholds[level];
    final int totalDiff = maxXp - minXp;
    final int currentDiff = xp - minXp;
    if (totalDiff == 0) return 0.0;
    return (currentDiff / totalDiff).clamp(0.0, 1.0);
  }

  Widget _buildChallengesTab(
    String userId,
    List<Map<String, dynamic>> challenges,
    List<Map<String, dynamic>> allUserChallenges,
  ) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildQuizCard(userId),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Challenges',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Browse'),
              onPressed: () =>
                  _showBrowseChallengesDialog(userId, allUserChallenges),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (challenges.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.assignment, size: 48, color: Colors.white24),
                SizedBox(height: 16),
                Text(
                  'No active challenges',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Browse and start a challenge to earn bonus XP!',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...challenges.map((c) {
            final progress = (c['progress_percent'] as int? ?? 0) / 100.0;
            return Card(
              color: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getCategoryIcon(c['category']),
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              c['category'].toString().toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c['difficulty'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c['challenge_name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedProgressBar(
                      value: progress,
                      backgroundColor: Colors.white10,
                      valueColor: AppColors.primaryBlue,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${c['progress_percent']}% Complete',
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '+${c['xp_reward']} XP',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (c['progress_percent'] < 100) ...[
                          TextButton(
                            onPressed: () async {
                              final newProg =
                                  (c['progress_percent'] as int? ?? 0) + 25;
                              if (newProg >= 100) {
                                await ref
                                    .read(gamificationRepositoryProvider)
                                    .completeChallenge(
                                      userId,
                                      c['challenge_id'],
                                    );
                                // Update profile user XP
                                final userProfile = await ref
                                    .read(userRepositoryProvider)
                                    .getUserProfile(userId);
                                if (userProfile != null) {
                                  final xpBonus = c['xp_reward'] as int? ?? 0;
                                  final newXp = userProfile.xp + xpBonus;
                                  final newLvl =
                                      GamificationEngine.getLevelFromXp(newXp);
                                  await ref
                                      .read(userRepositoryProvider)
                                      .saveUserProfile(
                                        userProfile.copyWith(
                                          xp: newXp,
                                          level: newLvl,
                                        ),
                                      );
                                  ref.invalidate(userProfileProvider(userId));

                                  if (mounted) {
                                    CelebrationModal.showChallengeComplete(
                                      context,
                                      c['challenge_name'],
                                      xpBonus,
                                    );
                                    if (newLvl > userProfile.level) {
                                      Future.delayed(
                                        const Duration(milliseconds: 1500),
                                        () {
                                          if (mounted) {
                                            CelebrationModal.showLevelUp(
                                              context,
                                              newLvl,
                                              GamificationEngine.getLevelTitle(
                                                newLvl,
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    }
                                  }
                                }
                              } else {
                                await ref
                                    .read(gamificationRepositoryProvider)
                                    .updateChallengeProgress(
                                      userId,
                                      c['challenge_id'],
                                      newProg,
                                    );
                              }
                              ref.invalidate(activeChallengesProvider(userId));
                              ref.invalidate(userChallengesProvider(userId));
                            },
                            child: const Text('Log Progress'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  IconData _getBadgeIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'directions_car':
        return Icons.directions_car;
      case 'restaurant':
        return Icons.restaurant;
      case 'bolt':
        return Icons.bolt;
      case 'eco':
        return Icons.eco;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'psychology':
        return Icons.psychology;
      case 'star':
        return Icons.star;
      case 'park':
        return Icons.park;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'shield':
        return Icons.shield;
      default:
        return Icons.stars;
    }
  }

  Widget _buildBadgesTab(List<Map<String, dynamic>> earned) {
    final earnedNames = earned.map((b) => b['badge_name'] as String).toSet();
    final badgeCatalogAsync = ref.watch(badgeCatalogProvider);

    final catalogBadges =
        badgeCatalogAsync.value ?? GamificationRepository.defaultBadgeCatalog;

    final List<Map<String, dynamic>> categoryBadges = catalogBadges
        .where((b) => !(b['is_special'] as bool? ?? false))
        .map(
          (b) => {
            'name': b['badge_name'],
            'desc': b['description'],
            'icon': _getBadgeIcon(b['icon_name'] as String?),
            'criteria': b['description'],
          },
        )
        .toList();

    final List<Map<String, dynamic>> specialBadges = catalogBadges
        .where((b) => (b['is_special'] as bool? ?? false))
        .map(
          (b) => {
            'name': b['badge_name'],
            'desc': b['description'],
            'criteria': b['description'],
          },
        )
        .toList();

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: categoryBadges.length + specialBadges.length,
      itemBuilder: (context, index) {
        final isCategory = index < categoryBadges.length;
        final badge = isCategory
            ? categoryBadges[index]
            : specialBadges[index - categoryBadges.length];
        final isEarned = earnedNames.contains(badge['name']);

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      badge['icon'] ?? Icons.military_tech,
                      color: isEarned ? AppColors.primaryGreen : Colors.white24,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        badge['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEarned ? 'Status: Earned 🎉' : 'Status: Locked 🔒',
                      style: TextStyle(
                        color: isEarned
                            ? AppColors.primaryGreen
                            : AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      badge['desc'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'How to Earn:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge['criteria'] ??
                          'Awarded for completing specific carbon reduction actions.',
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEarned
                    ? AppColors.primaryGreen.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? AppColors.primaryGreen.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.02),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge['icon'] ?? Icons.military_tech,
                    color: isEarned ? AppColors.primaryGreen : Colors.white24,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  badge['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isEarned ? Colors.white : Colors.white30,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  badge['desc'],
                  style: TextStyle(
                    fontSize: 10,
                    color: isEarned
                        ? AppColors.textSecondaryDark
                        : Colors.white12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab(UserProfile profile, List<dynamic> entries) {
    final currentUserId = profile.id;
    final userCity = profile.city?.trim();
    final isCityTab = _leaderboardType == 'city';
    final hasCity = userCity != null && userCity.isNotEmpty;

    return Column(
      children: [
        // Sub-tabs for Leaderboard tiers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: AppColors.surfaceDark,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 16),
                ...['global', 'city', 'weekly_sprint', 'friends'].map((type) {
                  final isSelected = _leaderboardType == type;
                  final label = type == 'city' && hasCity
                      ? 'CITY (${userCity.toUpperCase()})'
                      : type.replaceAll('_', ' ').toUpperCase();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _leaderboardType = type;
                          });
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // City Banner Header if city tab is active
        if (isCityTab && hasCity)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eco-Warriors in $userCity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${entries.length} members',
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(leaderboardProvider(_leaderboardType));
            },
            child: isCityTab && !hasCity
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_city_outlined,
                              size: 40,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No City Set',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Set your city in your profile to view and compete with fellow eco-warriors in your city.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : entries.isEmpty
                ? Center(
                    child: Text(
                      isCityTab
                          ? 'No other users found in $userCity yet.'
                          : 'No entries found',
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isCurrentUser = entry.userId == currentUserId;
                      final rank = entry.rank ?? (index + 1);

                      Color rankColor = AppColors.textSecondaryDark;
                      if (rank == 1) {
                        rankColor = const Color(0xFFFFD700); // Gold
                      } else if (rank == 2) {
                        rankColor = const Color(0xFFC0C0C0); // Silver
                      } else if (rank == 3) {
                        rankColor = const Color(0xFFCD7F32); // Bronze
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? AppColors.primaryGreen.withValues(alpha: 0.15)
                              : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrentUser
                                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                alignment: Alignment.center,
                                child: Text(
                                  '#$rank',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: rankColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              UserAvatar(
                                avatarUrl: entry.avatarUrl,
                                name: entry.name,
                                radius: 18,
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Level ${entry.level}',
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '${entry.xp} XP',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizCard(String userId) {
    final quizAsync = ref.watch(activeQuizProvider(userId));

    return quizAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (quizData) {
        final quiz = quizData['quiz'] as Quiz;
        final attempt = quizData['attempt'] as QuizAttemptResult?;
        final status = quizData['status'] as QuizStatus;

        final remaining = QuizEngine.getRemainingWindowDuration(
          quiz: quiz,
          now: DateTime.now(),
        );

        final hoursLeft = remaining.inHours;
        final minsLeft = remaining.inMinutes % 60;

        Widget actionWidget;
        String badgeText;
        Color badgeColor;

        if (status == QuizStatus.available) {
          badgeText = '${hoursLeft}h ${minsLeft}m left';
          badgeColor = Colors.amber;
          actionWidget = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Take Quiz'),
            onPressed: () => QuizModal.show(context, userId, quiz),
          );
        } else if (status == QuizStatus.completed) {
          badgeText = 'Completed 🌟';
          badgeColor = AppColors.primaryGreen;
          actionWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Score: ${attempt?.score ?? 0}/${attempt?.totalQuestions ?? 5} · +${attempt?.xpEarned ?? 0} XP',
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
        } else {
          badgeText = 'Expired';
          badgeColor = Colors.grey;
          actionWidget = const Text(
            'Next quiz: Tue & Fri 9 AM',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: status == QuizStatus.available
                  ? AppColors.primaryGreen.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: status == QuizStatus.available ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.psychology,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        quiz.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.topic,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Earn up to 130 XP · 48h Window',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actionWidget,
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'transport':
        return Icons.directions_car;
      case 'food':
        return Icons.restaurant;
      case 'energy':
        return Icons.bolt;
      case 'nature':
        return Icons.eco;
      default:
        return Icons.shopping_bag;
    }
  }

  void _showBrowseChallengesDialog(
    String userId,
    List<Map<String, dynamic>> userChallenges,
  ) {
    final catalogAsync = ref.read(availableChallengesCatalogProvider);
    final challengeLibrary = catalogAsync.value ?? _challengeLibrary;

    final challengeRecords = <String, Map<String, dynamic>>{};
    for (final row in userChallenges) {
      final cId = row['challenge_id'] as String?;
      if (cId != null) {
        challengeRecords[cId] = row;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text(
            'Browse Challenges',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: ListView.builder(
              itemCount: challengeLibrary.length,
              itemBuilder: (context, index) {
                final c = challengeLibrary[index];
                final id = c['id'] as String;
                final record = challengeRecords[id];

                final isEnrolled =
                    record != null && record['completed_at'] == null;

                bool isOnCooldown = false;
                int remainingDays = 0;

                if (record != null && record['completed_at'] != null) {
                  final completedAtStr = record['completed_at'] as String?;
                  if (completedAtStr != null) {
                    final completedAt = DateTime.tryParse(completedAtStr);
                    final difficulty = (c['difficulty'] ?? 'Easy').toString();
                    final duration = c['duration'] as int?;

                    isOnCooldown = GamificationEngine.isChallengeOnCooldown(
                      difficulty: difficulty,
                      completedAt: completedAt,
                      now: DateTime.now(),
                      durationDays: duration,
                    );
                    if (isOnCooldown) {
                      remainingDays =
                          GamificationEngine.getRemainingCooldownDays(
                            difficulty: difficulty,
                            completedAt: completedAt,
                            now: DateTime.now(),
                            durationDays: duration,
                          );
                      if (remainingDays < 1) remainingDays = 1;
                    }
                  }
                }

                Widget trailingWidget;
                if (isEnrolled) {
                  trailingWidget = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                } else if (isOnCooldown) {
                  trailingWidget = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cooldown (${remainingDays}d)',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                } else {
                  trailingWidget = ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await ref
                          .read(gamificationRepositoryProvider)
                          .enrollInChallenge(userId, c);
                      ref.invalidate(activeChallengesProvider(userId));
                      ref.invalidate(userChallengesProvider(userId));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Start'),
                  );
                }

                return ListTile(
                  leading: Icon(
                    _getCategoryIcon(c['category']),
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(
                    c['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '+${c['xp']} XP · ${c['difficulty']} (${c['duration']}d)',
                    style: const TextStyle(color: AppColors.textSecondaryDark),
                  ),
                  trailing: trailingWidget,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
