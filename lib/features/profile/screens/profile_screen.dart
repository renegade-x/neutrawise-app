import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/repositories/gamification_repository.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/widgets/animated_progress_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _darkMode = true;
  bool _loadingPrefs = true;
  Map<String, dynamic> _notifPrefs = {};
  int _completedChallenges = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndStats();
  }

  void _loadPreferencesAndStats() async {
    final user = ref.read(authProvider).user;
    if (user != null) {
      final userRepo = ref.read(userRepositoryProvider);
      final gamificationRepo = ref.read(gamificationRepositoryProvider);
      final prefs = await userRepo.getNotificationPreferences(user.id);
      final completedCount = await gamificationRepo.getCompletedChallengesCount(
        user.id,
      );

      if (mounted) {
        setState(() {
          _notifPrefs = prefs;
          _completedChallenges = completedCount;
          _loadingPrefs = false;
        });
      }
    }
  }

  void _savePrefs() async {
    final user = ref.read(authProvider).user;
    if (user != null) {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.saveNotificationPreferences(user.id, _notifPrefs);
    }
  }

  IconData _getBadgeIcon(String name) {
    switch (name) {
      case 'Road to Green':
        return Icons.directions_car;
      case 'Conscious Plate':
        return Icons.restaurant;
      case 'Power Saver':
        return Icons.bolt;
      case 'Nature Keeper':
        return Icons.eco;
      case 'Mindful Consumer':
        return Icons.shopping_bag;
      default:
        return Icons.military_tech;
    }
  }

  void _showBadgeDialog(String badgeName, String defaultDesc) {
    final metadata = GamificationEngine.badgeMetadata.firstWhere(
      (m) => m['name'] == badgeName,
      orElse: () => {
        'name': badgeName,
        'desc': defaultDesc,
        'criteria': 'Awarded for completing specific carbon reduction actions.',
      },
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _getBadgeIcon(badgeName),
              color: AppColors.primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                badgeName,
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
            const Text(
              'Status: Earned 🎉',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              metadata['desc'] ?? defaultDesc,
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
              metadata['criteria'] ??
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

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Header Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primaryGreen.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.email ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Stats Strip Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          'CO₂ Saved',
                          '${profile.totalCo2Saved.toStringAsFixed(1)} kg',
                        ),
                        _buildStatItem(
                          'Streak',
                          '${profile.currentStreak} days',
                        ),
                        _buildStatItem('Days Active', '${profile.daysActive}'),
                        _buildStatItem('Challenges', '$_completedChallenges'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Level card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Level $currentLevel: $levelTitle',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Icon(
                                Icons.military_tech,
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedProgressBar(
                            value: levelProgress,
                            backgroundColor: Colors.white10,
                            valueColor: AppColors.primaryGreen,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            xpToNext > 0
                                ? '$xpToNext XP to next level'
                                : 'Max Level Reached',
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Badge Showcase (Horizontal list)
                    const Text(
                      'Earned Badges',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    badgesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) =>
                          Center(child: Text('Error loading badges: $e')),
                      data: (badges) {
                        if (badges.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'No badges earned yet. Keep completing challenges!',
                              style: TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }
                        return SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: badges.length,
                            itemBuilder: (context, index) {
                              final b = badges[index];
                              final badgeName = b['badge_name'] as String;
                              final badgeDesc =
                                  b['badge_desc'] as String? ?? '';
                              return GestureDetector(
                                onTap: () =>
                                    _showBadgeDialog(badgeName, badgeDesc),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getBadgeIcon(badgeName),
                                        color: AppColors.warning,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        badgeName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Settings Section
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Dark Mode',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _darkMode,
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged: (v) {
                        setState(() {
                          _darkMode = v;
                        });
                      },
                    ),
                    const Divider(color: Colors.white10),

                    // Notifications Settings
                    if (!_loadingPrefs) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'Notification Preferences',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildNotifSwitch(
                        'Daily Log Reminder',
                        'daily_log_reminder',
                      ),
                      _buildNotifSwitch('Streak Warnings', 'streak_warnings'),
                      _buildNotifSwitch(
                        'Challenge Reminders',
                        'challenge_reminders',
                      ),
                      _buildNotifSwitch(
                        'Leaderboard Overtake',
                        'leaderboard_overtake',
                      ),
                      _buildNotifSwitch('Quiz Notifications', 'quiz_available'),
                    ],

                    const Divider(color: Colors.white10),
                    ListTile(
                      title: const Text(
                        'Edit Profile & Baseline',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white54,
                      ),
                      onTap: () {
                        context.push('/profile-setup');
                      },
                    ),
                    const Divider(color: Colors.white10),

                    // Account Actions
                    ListTile(
                      title: const Text(
                        'Change Password',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.white54,
                      ),
                      onTap: () => _showChangePasswordDialog(),
                    ),
                    const Divider(color: Colors.white10),
                    ListTile(
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      trailing: const Icon(
                        Icons.logout,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      onTap: () {
                        ref.read(authProvider.notifier).signOut();
                      },
                    ),
                    const Divider(color: Colors.white10),
                    ListTile(
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      trailing: const Icon(
                        Icons.delete_forever,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      onTap: () => _showDeleteAccountDialog(),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildNotifSwitch(String label, String key) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
      value: _notifPrefs[key] ?? true,
      activeThumbColor: AppColors.primaryGreen,
      onChanged: (v) {
        setState(() {
          _notifPrefs[key] = v;
        });
        _savePrefs();
      },
    );
  }

  void _showChangePasswordDialog() {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text(
            'Change Password',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: passwordCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'New Password',
              labelStyle: TextStyle(color: AppColors.textSecondaryDark),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passwordCtrl.text.isNotEmpty) {
                  // In Supabase, update password
                  await ref
                      .read(authProvider.notifier)
                      .updatePassword(passwordCtrl.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account? This action is irreversible and all your daily logs and progress will be deleted.',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                // Perform delete account cascade
                await ref.read(authProvider.notifier).deleteAccount();
                if (context.mounted) {
                  Navigator.pop(context);
                  context.go('/login');
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }
}
