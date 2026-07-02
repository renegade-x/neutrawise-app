import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/repositories/activity_repository.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/features/activity/screens/activity_log_sheet.dart';
import 'package:neutrawise/features/insights/screens/insights_screen.dart';
import 'package:neutrawise/features/gamification/screens/gamification_screen.dart';
import 'package:neutrawise/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:neutrawise/features/profile/screens/profile_screen.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/services/push_notification_service.dart';
import 'package:neutrawise/widgets/celebration_modal.dart';
import 'package:neutrawise/routing/router.dart';
class ActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int value) => state = value;
}

final activeTabProvider = NotifierProvider<ActiveTabNotifier, int>(ActiveTabNotifier.new);

final recentLogsProvider = StreamProvider.family<List<DailyLog>, String>((
  ref,
  userId,
) {
  return ref.watch(activityRepositoryProvider).watchRecentLogs(userId);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final List<Widget> _screens = const [
    _DashboardContent(),
    InsightsScreen(),
    GamificationScreen(),
    AIAssistantScreen(),
    ProfileScreen(),
  ];

  late final PageController _pageController;
  RealtimeChannel? _badgesChannel;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(activeTabProvider));
    PushNotificationService.initialize(ref);

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      _subscribeToBadges(userId);
    }
  }

  void _subscribeToBadges(String userId) {
    try {
      _badgesChannel = Supabase.instance.client
          .channel('badges_celebration')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'badges',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newBadge = payload.newRecord;
              final badgeName = newBadge['badge_name'] as String? ?? 'Badge';
              final badgeDesc = newBadge['description'] as String? ?? '';
              final context = rootNavigatorKey.currentContext;
              if (context != null) {
                CelebrationModal.showBadgeEarned(context, badgeName, badgeDesc);
              }
            },
          );
      _badgesChannel?.subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_badgesChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_badgesChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final logsAsync = ref.watch(recentLogsProvider(user.id));
    final currentIndex = ref.watch(activeTabProvider);

    ref.listen<int>(activeTabProvider, (prev, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.textSecondaryDark,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          ref.read(activeTabProvider.notifier).setTab(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Eco Club',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            activeIcon: Icon(Icons.psychology),
            label: 'AI Coach',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: (currentIndex == 0 || currentIndex == 1)
          ? logsAsync.maybeWhen(
              data: (logs) {
                final todayLog = logs
                    .where(
                      (l) =>
                          l.date ==
                          DateTime.now().toIso8601String().substring(0, 10),
                    )
                    .firstOrNull;
                return FloatingActionButton(
                  backgroundColor: AppColors.primaryGreen,
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.backgroundDark,
                      builder: (context) =>
                          ActivityLogSheet(existingLog: todayLog),
                    );
                  },
                ).animate().scale(
                  delay: 200.ms,
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                );
              },
              orElse: () => FloatingActionButton(
                backgroundColor: AppColors.primaryGreen,
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.backgroundDark,
                    builder: (context) => const ActivityLogSheet(),
                  );
                },
              ).animate().scale(
                delay: 200.ms,
                duration: 400.ms,
                curve: Curves.elasticOut,
              ),
            )
          : null,
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final profileAsync = ref.watch(userProfileProvider(user.id));
    final logsAsync = ref.watch(recentLogsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NeutraWise',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading logs: $e')),
            data: (logs) {
              final todayLog = logs
                  .where(
                    (l) =>
                        l.date ==
                        DateTime.now().toIso8601String().substring(0, 10),
                  )
                  .firstOrNull;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
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
                                'Hello, ${profile.name}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Let's make an impact today.",
                                style: TextStyle(
                                  color: AppColors.textSecondaryDark,
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
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile.currentStreak}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Ring Chart
                      Center(
                        child: AnimatedRingChart(
                          transportCo2: todayLog?.transportCo2 ?? 0,
                          foodCo2: todayLog?.foodCo2 ?? 0,
                          energyCo2: todayLog?.energyCo2 ?? 0,
                          baseline: profile.totalDailyBaselineCo2 ?? 1.0,
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  (todayLog?.totalDailyCo2 ?? 0)
                                      .toStringAsFixed(1),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        fontSize: 48,
                                        color: Colors.white,
                                      ),
                                ),
                                const Text(
                                  'kg CO₂e',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'vs ${(profile.totalDailyBaselineCo2 ?? 0).toStringAsFixed(1)} avg',
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Category Cards
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryCard(
                              title: 'Transport',
                              co2: todayLog?.transportCo2 ?? 0,
                              icon: Icons.directions_car,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CategoryCard(
                              title: 'Food',
                              co2: todayLog?.foodCo2 ?? 0,
                              icon: Icons.restaurant,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CategoryCard(
                              title: 'Energy',
                              co2: todayLog?.energyCo2 ?? 0,
                              icon: Icons.bolt,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const DailyEcoTipWidget(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final double co2;
  final IconData icon;
  final Color color;

  const _CategoryCard({
    required this.title,
    required this.co2,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '${co2.toStringAsFixed(1)} kg',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedRingChart extends StatefulWidget {
  final double transportCo2;
  final double foodCo2;
  final double energyCo2;
  final double baseline;
  final Widget child;

  const AnimatedRingChart({
    super.key,
    required this.transportCo2,
    required this.foodCo2,
    required this.energyCo2,
    required this.baseline,
    required this.child,
  });

  @override
  State<AnimatedRingChart> createState() => _AnimatedRingChartState();
}

class _AnimatedRingChartState extends State<AnimatedRingChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedRingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transportCo2 != widget.transportCo2 ||
        oldWidget.foodCo2 != widget.foodCo2 ||
        oldWidget.energyCo2 != widget.energyCo2 ||
        oldWidget.baseline != widget.baseline) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(220, 220),
          painter: RingChartPainter(
            transportCo2: widget.transportCo2,
            foodCo2: widget.foodCo2,
            energyCo2: widget.energyCo2,
            baseline: widget.baseline,
            progress: _animation.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class RingChartPainter extends CustomPainter {
  final double transportCo2;
  final double foodCo2;
  final double energyCo2;
  final double baseline;
  final double progress;

  RingChartPainter({
    required this.transportCo2,
    required this.foodCo2,
    required this.energyCo2,
    required this.baseline,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    final paintBg = Paint()
      ..color = AppColors.surfaceDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paintBg);

    final total = transportCo2 + foodCo2 + energyCo2;
    if (total == 0) return;

    double startAngle = -pi / 2;
    final sweepTotal = (total / baseline).clamp(0.0, 1.0) * 2 * pi * progress;

    void drawSegment(double co2, Color color) {
      if (co2 == 0) return;
      final sweepAngle = (co2 / total) * sweepTotal;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(transportCo2, AppColors.primaryBlue);
    drawSegment(foodCo2, AppColors.primaryGreen);
    drawSegment(energyCo2, AppColors.warning);
  }

  @override
  bool shouldRepaint(covariant RingChartPainter oldDelegate) {
    return oldDelegate.transportCo2 != transportCo2 ||
        oldDelegate.foodCo2 != foodCo2 ||
        oldDelegate.energyCo2 != energyCo2 ||
        oldDelegate.baseline != baseline ||
        oldDelegate.progress != progress;
  }
}

class DailyEcoTipWidget extends StatefulWidget {
  const DailyEcoTipWidget({super.key});

  @override
  State<DailyEcoTipWidget> createState() => _DailyEcoTipWidgetState();
}

class _DailyEcoTipWidgetState extends State<DailyEcoTipWidget> {
  int _currentIndex = 0;
  Timer? _timer;

  final List<String> _tips = [
    'Unplug electronics when not in use. Even in standby mode, devices draw phantom power.',
    'Switch to a plant-based meal once a week. Doing so can save up to 8kg of CO₂ per meal.',
    'Lower your thermostat by just 1°C. This can reduce your energy bill and heating footprint by up to 10%.',
    'Wash your clothes in cold water. About 90% of the energy consumed by a washing machine goes to heating water.',
    'Car pool, walk, or bike for short trips. Transport accounts for a significant portion of personal emissions.',
    'Avoid single-use plastics. Carry a reusable water bottle and shopping bag wherever you go.',
    'Install a low-flow showerhead. This saves both water and the energy needed to heat it.',
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _nextTip() {
    _timer?.cancel();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _tips.length;
    });
    _startTimer();
  }

  void _prevTip() {
    _timer?.cancel();
    setState(() {
      _currentIndex = (_currentIndex - 1 + _tips.length) % _tips.length;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Daily Eco Tip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white60,
                      size: 20,
                    ),
                    onPressed: _prevTip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white60,
                      size: 20,
                    ),
                    onPressed: _nextTip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _tips[_currentIndex],
                key: ValueKey<int>(_currentIndex),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
