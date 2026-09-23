import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/widgets/modals/error_popup.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  Map<String, dynamic> _notifPrefs = {
    'daily_log_reminder': true,
    'streak_warnings': true,
    'challenge_reminders': true,
    'leaderboard_overtake': true,
    'quiz_available': true,
    'weekly_summary': true,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = ref.read(authProvider).user;
    if (user != null) {
      try {
        final userRepo = ref.read(userRepositoryProvider);
        final prefs = await userRepo.getNotificationPreferences(user.id);
        if (mounted) {
          setState(() {
            if (prefs.isNotEmpty) {
              _notifPrefs = prefs;
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    setState(() {
      _notifPrefs[key] = value;
    });

    final user = ref.read(authProvider).user;
    if (user != null) {
      try {
        final userRepo = ref.read(userRepositoryProvider);
        await userRepo.saveNotificationPreferences(user.id, _notifPrefs);
      } catch (e) {
        if (mounted) {
          // Revert optimistic update on failure
          setState(() {
            _notifPrefs[key] = !value;
          });
          ErrorPopup.showFromException(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Notification Preferences',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose what updates, reminders, and alerts you want to receive to stay motivated on your carbon reduction journey.',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border(context),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildPreferenceTile(
                          title: 'Daily Log Reminder',
                          subtitle:
                              'Get a friendly evening prompt to log your daily travel, food, and energy.',
                          icon: Icons.alarm_rounded,
                          prefKey: 'daily_log_reminder',
                          isFirst: true,
                        ),
                        _buildDivider(),
                        _buildPreferenceTile(
                          title: 'Streak Warnings',
                          subtitle:
                              'Receive timely alerts before your daily logging streak expires.',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orange,
                          prefKey: 'streak_warnings',
                        ),
                        _buildDivider(),
                        _buildPreferenceTile(
                          title: 'Challenge Reminders',
                          subtitle:
                              'Stay updated on your active eco challenges and milestone progress.',
                          icon: Icons.emoji_events_rounded,
                          iconColor: Colors.amber,
                          prefKey: 'challenge_reminders',
                        ),
                        _buildDivider(),
                        _buildPreferenceTile(
                          title: 'Leaderboard Overtake',
                          subtitle:
                              'Get notified when other users pass your rank on the leaderboard.',
                          icon: Icons.leaderboard_rounded,
                          iconColor: Colors.blueAccent,
                          prefKey: 'leaderboard_overtake',
                        ),
                        _buildDivider(),
                        _buildPreferenceTile(
                          title: 'Quiz Notifications',
                          subtitle:
                              'Be alerted whenever a new 48-hour climate quiz becomes available.',
                          icon: Icons.quiz_rounded,
                          iconColor: Colors.teal,
                          prefKey: 'quiz_available',
                        ),
                        _buildDivider(),
                        _buildPreferenceTile(
                          title: 'Weekly Summary',
                          subtitle:
                              'Receive a comprehensive recap of your weekly CO₂ savings and XP earned.',
                          icon: Icons.insights_rounded,
                          iconColor: AppColors.primaryGreen,
                          prefKey: 'weekly_summary',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 16,
      color: AppColors.divider(context),
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required String prefKey,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final bool isEnabled = _notifPrefs[prefKey] ?? true;
    final Color effectiveIconColor = iconColor ?? AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: effectiveIconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: isEnabled,
            activeTrackColor: AppColors.primaryGreen,
            activeThumbColor: Colors.white,
            onChanged: (val) => _updatePreference(prefKey, val),
          ),
        ],
      ),
    );
  }
}
