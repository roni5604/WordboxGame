import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/motion/motion.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/push_service.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/pressable.dart';
import '../../providers/social_provider.dart';
import '../ads/rewarded_gift_button.dart';
import '../../data/models/player_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../../game_engine/daily_challenge.dart';
import '../onboarding/widgets/mini_grid_demo.dart';
import '../profile/widgets/avatar_widget.dart';
import 'widgets/daily_hint_dialog.dart';

/// תפריט ראשי - שער הכניסה למשחק: התחלת קמפיין, רב-משתתפים, הדרכה
/// וחוקי המשחק. מפת השלבים עצמה נמצאת ב-/campaign (ראה [CampaignMapScreen]).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _dailyRewardChecked = false;

  Future<void> _maybeShowDailyReward(
    PlayerProfile profile,
    bool isGuest,
  ) async {
    if (_dailyRewardChecked) return;
    _dailyRewardChecked = true;
    final ads = ref.read(adsGatewayProvider);
    if (ads.isSupported) {
      await ads.ensureInitialized();
    }
    if (!mounted) return;
    // נפתחנו מלחיצה על התראה (למשל "האתגר היומי") - קודם לשם.
    final launchRoute = NotificationService.instance.takeLaunchRoute();
    if (launchRoute != null && launchRoute != '/home') {
      context.push(launchRoute);
      return;
    }
    if (isGuest) {
      await _maybeOfferNotifications(profile);
      return;
    }
    // בונוס הרמזים היומי שמור לחשבונות אמיתיים בלבד - זו אחת הסיבות
    // הכי טובות להירשם, אז אין טעם להציג אותו למי שעדיין אורח/ת.
    final reward = await ref
        .read(playerProfileProvider.notifier)
        .claimDailyHintIfAvailable();
    if (reward != null) {
      final item = 'daily_login_day_${reward.day}';
      if (reward.hintsAwarded > 0) {
        AnalyticsService.instance.earnVirtualCurrency(
          currency: 'hints',
          value: reward.hintsAwarded,
          source: 'daily',
          item: item,
        );
      }
      if (reward.coinsAwarded > 0) {
        AnalyticsService.instance.earnVirtualCurrency(
          currency: 'coins',
          value: reward.coinsAwarded,
          source: 'daily',
          item: item,
        );
      }
    }
    if (reward != null && mounted) {
      final offerExtra = ads.canRequestAds && ads.dailyBonusAdAvailable;
      await DailyBonus.show(
        context,
        reward,
        extraAction: offerExtra
            ? (_) => RewardedGiftButton(
                  label: 'עוד רמז אחד — צפו בפרסומת',
                  successLabel: 'קיבלתם רמז נוסף!',
                  icon: Icons.play_circle_fill_rounded,
                  style: RewardedButtonStyle.contrast,
                  placement: 'daily_bonus_extra_hint',
                  rewardCurrency: 'hints',
                  rewardAmount: 1,
                  onReward: () async {
                    await ref
                        .read(playerProfileProvider.notifier)
                        .grantHints(1);
                    await ref
                        .read(adsGatewayProvider)
                        .recordDailyBonusAdGranted();
                    ref.read(soundServiceProvider).playCoin();
                  },
                )
            : null,
      );
    }
    await _maybeOfferNotifications(profile);
  }

  /// פעם אחת, אחרי שלבי ההדרכה: מסבירים מה נשלח ורק אז מבקשים הרשאה
  /// מהמערכת (בקשה "קרה" בכניסה הראשונה נדחית ברוב המקרים, ואז אי אפשר
  /// לבקש שוב).
  Future<void> _maybeOfferNotifications(PlayerProfile profile) async {
    final service = NotificationService.instance;
    if (!await service.shouldOfferPermission(profile) || !mounted) return;
    await service.markOffered();
    if (!mounted) return;
    final yes = await showConfirmDialog(
      context,
      title: 'להזכיר לכם?',
      message: 'תזכורת אחת בערב כשהבונוס היומי מחכה או כשרצף האתגר היומי בסכנה, '
          'והודעה כשחבר/ה מזמין/ה אתכם למשחק. בלי הצפות.',
      confirmLabel: 'כן, תזכירו לי',
      cancelLabel: 'לא עכשיו',
      confirmPalette: CandyPalette.green,
      hero: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 56),
    );
    if (!yes || !mounted) return;
    final granted = await service.requestPermission();
    AnalyticsService.instance.settingsChange(setting: 'notifications', value: granted ? 'on' : 'denied');
    if (!granted) return;
    unawaited(PushService.instance.sync());
    if (!mounted) return;
    final user = ref.read(authStateProvider).valueOrNull;
    final latest = ref.read(playerProfileProvider).valueOrNull ?? profile;
    await service.reschedule(latest, isGuest: user == null || user.isAnonymous);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(playerProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = authUser == null || authUser.isAnonymous;
    final incomingRequests = ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;
    final onlineFriends = ref.watch(onlineFriendsCountProvider);
    final socialAvailable = ref.watch(socialRepositoryProvider).isAvailable;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: GameBackdrop(
        colors: const [Color(0xFFFF8A4C), Color(0xFFFF6A3D), Color(0xFFE8456B)],
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (e, st) => const Center(
            child: Text(
              'לא הצלחנו לטעון את הפרופיל. נסו שוב.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          data: (profile) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _maybeShowDailyReward(profile, isGuest),
            );

            // גלילה + גובה מינימלי = תוכן ממורכז יפה במסכים גבוהים, אך
            // לעולם לא "נחתך" מחוץ למסך במסכים קצרים/רחבים. הרקע ממשיך עד
            // קצות המסך (מאחורי ה-notch ופס הבית), והתוכן באזור הבטוח.
            return LayoutBuilder(
              builder: (context, constraints) {
                final topInset = context.safeTop;
                final bottomInset = context.safeBottom(min: 20, extra: 14);
                // טלפונים נמוכים (iPhone SE/8, אנדרואיד קטן): מקטינים את הדמות,
                // לוח ההדגמה והכותרת כך שכל המסך - כולל שורת הקיצורים
                // התחתונה - נכנס בלי גלילה.
                final usable = constraints.maxHeight - topInset - bottomInset;
                final compact = usable < 720;
                final tight = usable < 640;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - topInset - bottomInset).clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: AlignmentDirectional.centerStart,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _Pill(
                                            icon: Icons.star_rounded,
                                            iconColor: AppColors.star,
                                            label: '${profile.totalStars}',
                                          ),
                                          const SizedBox(width: 8),
                                          _Pill(
                                            icon: Icons.paid_rounded,
                                            iconColor: Colors.amberAccent,
                                            label: '${profile.coins}',
                                            onTap: () => context.push('/store?from=home_coins'),
                                          ),
                                          const SizedBox(width: 8),
                                          // רמזים שמורים לחשבונות אמיתיים בלבד.
                                          if (isGuest)
                                            _Pill(
                                              icon: Icons.lock_outline_rounded,
                                              iconColor: Colors.amberAccent,
                                              label: 'הרשמה לרמזים',
                                              onTap: () => context.push('/auth'),
                                            )
                                          else
                                            _Pill(
                                              icon: Icons.lightbulb_rounded,
                                              iconColor: AppColors.star,
                                              label: '${profile.hints}',
                                              onTap: () => context.push('/store?from=home_hints'),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CandyIconButton(
                                    icon: Icons.settings_rounded,
                                    size: 40,
                                    tooltip: 'הגדרות',
                                    onPressed: () => context.push('/settings'),
                                  ),
                                  const SizedBox(width: 8),
                                  Pressable(
                                    semanticLabel: 'פרופיל',
                                    onTap: () => context.push('/profile'),
                                    child: AvatarWidget(
                                      avatarId: profile.avatarId,
                                      size: 42,
                                      photoUrl: authUser?.photoUrl,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'שלום, ${profile.displayName}! 👋',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(),
                            const SizedBox(height: 4),
                            AnimatedAvatar(
                                  avatarId: profile.avatarId,
                                  size: tight ? 74 : (compact ? 88 : 118),
                                  photoUrl: authUser?.photoUrl,
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .moveY(
                                  begin: -6,
                                  end: 6,
                                  duration: 1600.ms,
                                  curve: Curves.easeInOut,
                                ),
                            SizedBox(height: compact ? 4 : 8),
                            AnimatedMiniGridDemo(
                              letters: const ['ל', 'ב', 'י', 'ז', 'ת', 'ק'],
                              columns: 3,
                              path: const [1, 2, 4],
                              tileSize: tight ? 40 : (compact ? 46 : 56),
                              spacing: compact ? 9 : 12,
                            ).animate().fadeIn(delay: 150.ms),
                            SizedBox(height: compact ? 4 : 8),
                            Text(
                              'מצא ת׳מילה',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 34 : 40,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFB4321F).withValues(alpha: 0.9),
                                    offset: const Offset(0, 4),
                                  ),
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ).animate().fadeIn().scale(
                              begin: const Offset(0.85, 0.85),
                              curve: Curves.elasticOut,
                              duration: 900.ms,
                            ),
                            const Text(
                              'משחקו של רוני מיכאלי',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, compact ? 10 : 16, 20, 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CandyButton(
                                        label: profile.highestUnlockedLevel > 1 ? 'המשך משחק' : 'שחקו!',
                                        subtitle: profile.highestUnlockedLevel > 1
                                            ? 'שלב ${profile.highestUnlockedLevel} מחכה לך'
                                            : null,
                                        icon: Icons.play_arrow_rounded,
                                        palette: CandyPalette.green,
                                        height: compact ? 66 : 74,
                                        fontSize: compact ? 22 : 24,
                                        onPressed: () => context.push('/campaign'),
                                      )
                                      .animate()
                                      .fadeIn(delay: 100.ms)
                                      .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack),
                                  SizedBox(height: compact ? 10 : 14),
                                  Row(
                                        children: [
                                          Expanded(
                                            child: CandyTile(
                                              icon: Icons.smart_toy_rounded,
                                              label: 'שחק נגד המחשב',
                                              subtitle: 'תחרות מול יריבים ממוחשבים',
                                              palette: CandyPalette.blue,
                                              height: compact ? 112 : 128,
                                              onPressed: () => context.push('/multiplayer/setup'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: CandyTile(
                                              icon: Icons.groups_rounded,
                                              label: 'שחק נגד חברים',
                                              subtitle: socialAvailable && onlineFriends > 0
                                                  ? '$onlineFriends חברים מחוברים'
                                                  : 'חדר פרטי בזמן אמת',
                                              palette: CandyPalette.purple,
                                              height: compact ? 112 : 128,
                                              badgeCount: incomingRequests,
                                              onPressed: () => context.push('/play/friends'),
                                            ),
                                          ),
                                        ],
                                      )
                                      .animate()
                                      .fadeIn(delay: 200.ms)
                                      .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack),
                                  SizedBox(height: compact ? 10 : 16),
                                  Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _RoundAction(
                                            icon: Icons.people_alt_rounded,
                                            label: 'חברים',
                                            palette: CandyPalette.pink,
                                            badgeCount: incomingRequests,
                                            onTap: () => context.push('/friends'),
                                          ),
                                          _RoundAction(
                                            icon: Icons.storefront_rounded,
                                            label: 'חנות',
                                            palette: CandyPalette.gold,
                                            onTap: () => context.push('/store?from=home'),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              final dailyPlayed = profile.playedDailyOn(
                                                DailyChallenge.dateKeyFor(DateTime.now()),
                                              );
                                              final action = _RoundAction(
                                                icon: Icons.calendar_today_rounded,
                                                label: 'אתגר יומי',
                                                palette: CandyPalette.orange,
                                                badgeCount: dailyPlayed ? null : 1,
                                                onTap: () => context.push('/daily'),
                                              );
                                              if (dailyPlayed) return action;
                                              // לא שוחק היום - פעימה עדינה שמזמינה לחזור.
                                              return action
                                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                                  .scaleXY(begin: 1, end: 1.07, duration: 900.ms, curve: Curves.easeInOut);
                                            },
                                          ),
                                          _RoundAction(
                                            icon: Icons.menu_book_rounded,
                                            label: 'חוקי המשחק',
                                            palette: CandyPalette.white,
                                            onTap: () => context.push('/rules'),
                                          ),
                                        ],
                                      )
                                      .animate()
                                      .fadeIn(delay: 320.ms)
                                      .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 6),
          // מספרים (מטבעות/כוכבים/רמזים) "סופרים" לערך החדש כשהוא משתנה -
          // חוזרים מתיבת מזל ורואים את המטבעות עולים.
          if (int.tryParse(label) case final value?)
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: value, end: value),
              duration: const Duration(milliseconds: 900),
              curve: Motion.out,
              builder: (context, v, _) => Text('$v', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            )
          else
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
    if (onTap == null) return pill;
    return Pressable(onTap: onTap, child: pill);
  }
}

/// כפתור עגול עם תווית מתחת (חברים / חנות / הדרכה / חוקים).
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final CandyPalette palette;
  final VoidCallback onTap;
  final int? badgeCount;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            IgnorePointer(
              child: CandyIconButton(
                icon: icon,
                palette: palette,
                size: 56,
                onPressed: () {},
                badgeCount: badgeCount,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
