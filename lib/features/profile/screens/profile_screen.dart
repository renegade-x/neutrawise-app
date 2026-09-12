import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/providers/theme_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/repositories/gamification_repository.dart';
import 'package:neutrawise/data/repositories/leaderboard_repository.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/widgets/animated_progress_bar.dart';
import 'package:neutrawise/widgets/user_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loadingPrefs = true;
  Map<String, dynamic> _notifPrefs = {};
  int _completedChallenges = 0;
  final ImagePicker _picker = ImagePicker();

  static const List<Map<String, String>> _ecoAvatars = [
    {'emoji': '🌿', 'name': 'Leaf Guardian'},
    {'emoji': '☀️', 'name': 'Solar Hero'},
    {'emoji': '🌊', 'name': 'Ocean Keeper'},
    {'emoji': '⚡', 'name': 'Energy Master'},
    {'emoji': '🌲', 'name': 'Forest Ranger'},
    {'emoji': '🚲', 'name': 'Eco Cyclist'},
    {'emoji': '🐾', 'name': 'Wildlife Guard'},
    {'emoji': '🌍', 'name': 'Earth Steward'},
    {'emoji': '🌸', 'name': 'Eco Bloom'},
    {'emoji': '🦊', 'name': 'Forest Fox'},
    {'emoji': '🐢', 'name': 'Sea Turtle'},
    {'emoji': '🐝', 'name': 'Honey Bee'},
  ];

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

  Future<void> _updateAvatar(UserProfile profile, String? newAvatarUrl) async {
    try {
      final updated = profile.copyWith(avatarUrl: newAvatarUrl);
      await ref.read(userRepositoryProvider).saveUserProfile(updated);
      ref.invalidate(userProfileProvider(profile.id));
      ref.invalidate(leaderboardProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newAvatarUrl == null
                  ? 'Profile picture removed.'
                  : 'Profile picture updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(UserProfile profile, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await _updateAvatar(profile, base64String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImageUrlDialog(UserProfile profile) {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Image URL',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: urlCtrl,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: 'https://example.com/avatar.jpg',
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context).withValues(alpha: 0.5),
            ),
            labelText: 'Image Link',
            labelStyle: TextStyle(color: AppColors.textSecondary(context)),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                _updateAvatar(profile, url);
              }
            },
            child: const Text('Set Image'),
          ),
        ],
      ),
    );
  }

  void _showProfilePictureModal(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profile Picture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Option 1: Choose Eco Avatar Preset
            Text(
              'Choose Eco Avatar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _ecoAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = _ecoAvatars[index];
                  final emoji = avatar['emoji']!;
                  final avatarValue = 'emoji:$emoji';
                  final isSelected = profile.avatarUrl == avatarValue;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateAvatar(profile, avatarValue);
                    },
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreen.withValues(alpha: 0.15)
                            : AppColors.border(context).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.border(context),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(
                            avatar['name']!,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : AppColors.textSecondary(context),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: AppColors.divider(context)),
            const SizedBox(height: 12),

            // Option 2 & 3 & 4: Upload Photo / Camera / URL
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primaryGreen,
              ),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: AppColors.textPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(profile, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppColors.primaryGreen,
              ),
              title: Text(
                'Take a Photo',
                style: TextStyle(color: AppColors.textPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(profile, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.primaryGreen),
              title: Text(
                'Enter Image URL',
                style: TextStyle(color: AppColors.textPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showImageUrlDialog(profile);
              },
            ),
            if (profile.avatarUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Remove Profile Picture',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateAvatar(profile, null);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileModal(UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    final cityCtrl = TextEditingController(text: profile.city ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Edit Profile Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.person,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityCtrl,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'e.g. London, New York, Tokyo',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary(
                    context,
                  ).withValues(alpha: 0.5),
                ),
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.location_city,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final newCity = cityCtrl.text.trim();
                if (newName.isEmpty) return;

                final updated = profile.copyWith(
                  name: newName,
                  city: newCity.isEmpty ? null : newCity,
                );

                await ref.read(userRepositoryProvider).saveUserProfile(updated);
                ref.invalidate(userProfileProvider(profile.id));
                ref.invalidate(leaderboardProvider);

                if (mounted) {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile details updated!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Change Password',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newPass = newPassCtrl.text;
                      final confirmPass = confirmPassCtrl.text;

                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (newPass != confirmPass) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      final error = await ref
                          .read(authProvider.notifier)
                          .updatePassword(newPass);
                      setDialogState(() => isLoading = false);

                      if (mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        } else {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is irreversible. All your data, badges, and progress will be permanently deleted.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Enter Password to Confirm',
                  labelStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      final error = await ref
                          .read(authProvider.notifier)
                          .deleteAccount();
                      setDialogState(() => isLoading = false);

                      if (mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        } else {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Delete Forever',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDialog(String name, String desc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.military_tech, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          desc,
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getBadgeIcon(String badgeName) {
    switch (badgeName.toLowerCase()) {
      case 'eco pioneer':
      case 'first steps':
        return Icons.eco;
      case 'streak master':
      case '7-day streak':
      case '30-day streak':
        return Icons.local_fire_department;
      case 'zero emission day':
      case 'green commuter':
        return Icons.directions_car;
      case 'plant power':
      case 'veggie lover':
        return Icons.restaurant;
      case 'energy saver':
      case 'solar hero':
        return Icons.bolt;
      default:
        return Icons.military_tech;
    }
  }

  Widget _buildNotifSwitch(String title, String key) {
    final bool value = _notifPrefs[key] ?? true;
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
      ),
      value: value,
      activeThumbColor: AppColors.primaryGreen,
      dense: true,
      onChanged: (val) {
        setState(() {
          _notifPrefs[key] = val;
        });
        _savePrefs();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: Text(
            'Not logged in',
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
        ),
      );
    }

    final profileAsync = ref.watch(userProfileProvider(user.id));
    final badgesAsync = ref.watch(userBadgesProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Error: $e',
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(
                'Profile not found',
                style: TextStyle(color: AppColors.textPrimary(context)),
              ),
            );
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
                // User Header Info with Avatar & Edit Options
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatar(
                      avatarUrl: profile.avatarUrl,
                      name: profile.name,
                      radius: 38,
                      showEditBadge: true,
                      onTap: () => _showProfilePictureModal(profile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: AppColors.primaryGreen,
                                ),
                                onPressed: () => _showEditProfileModal(profile),
                                tooltip: 'Edit Profile Details',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          Text(
                            profile.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _showEditProfileModal(profile),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 13,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    profile.city != null &&
                                            profile.city!.trim().isNotEmpty
                                        ? profile.city!.trim()
                                        : 'Add City',
                                    style: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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
                    _buildStatItem('Streak', '${profile.currentStreak} days'),
                    _buildStatItem('Days Active', '${profile.daysActive}'),
                    _buildStatItem('Level', '$currentLevel'),
                  ],
                ),
                const SizedBox(height: 32),

                // Level Banner Card
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
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
                                'Level $currentLevel: $levelTitle',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currentXp XP Total',
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield,
                              color: AppColors.primaryGreen,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedProgressBar(
                        value: levelProgress,
                        valueColor: AppColors.primaryGreen,
                        backgroundColor: AppColors.divider(context),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        xpToNext > 0
                            ? '$xpToNext XP to Level ${currentLevel + 1}'
                            : 'Max Level Reached!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Earned Badges Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Badges Earned',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    badgesAsync.maybeWhen(
                      data: (badges) => Text(
                        '${badges.length} Unlocked',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      orElse: () => const SizedBox(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                badgesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text(
                    'Failed to load badges: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  data: (badges) {
                    if (badges.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'No badges earned yet. Complete challenges to unlock them!',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: badges.length,
                        itemBuilder: (context, index) {
                          final badge = badges[index];
                          final badgeName = badge['badge_name'] ?? 'Badge';
                          final badgeDesc =
                              badge['badge_description'] ??
                              'Great achievement!';

                          return GestureDetector(
                            onTap: () => _showBadgeDialog(badgeName, badgeDesc),
                            child: Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getBadgeIcon(badgeName),
                                      color: AppColors.primaryGreen,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    badgeName,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary(context),
                                      fontSize: 10,
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

                // Challenges Summary Card
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: AppColors.primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed Challenges',
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_completedChallenges challenges accomplished',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Settings Section
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(
                    'Dark Mode',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                  value: isDarkMode,
                  activeThumbColor: AppColors.primaryGreen,
                  onChanged: (v) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                Divider(color: AppColors.divider(context)),

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
                  _buildNotifSwitch('Daily Log Reminder', 'daily_log_reminder'),
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
                  _buildNotifSwitch('Weekly Summary', 'weekly_summary'),
                ],

                Divider(color: AppColors.divider(context)),
                ListTile(
                  title: Text(
                    'Edit Profile & Baseline',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary(context),
                  ),
                  onTap: () {
                    context.push('/profile-setup');
                  },
                ),
                Divider(color: AppColors.divider(context)),

                // Account Actions
                ListTile(
                  title: Text(
                    'Change Password',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                  trailing: Icon(
                    Icons.lock,
                    size: 16,
                    color: AppColors.textSecondary(context),
                  ),
                  onTap: () => _showChangePasswordDialog(),
                ),
                Divider(color: AppColors.divider(context)),
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
                Divider(color: AppColors.divider(context)),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
