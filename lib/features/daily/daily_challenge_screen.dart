import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../game_engine/daily_challenge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/social_provider.dart';
import '../profile/widgets/avatar_widget.dart';
import '../share/share_achievement_sheet.dart';
import 'daily_challenge_game_screen.dart';
import '../../core/feedback/haptics.dart';

/// צבעי האתגר היומי - שקיעה זהובה-ורודה.
const kDailyGradient = [Color(0xFFFFB347), Color(0xFFFF6F91), Color(0xFFB45CFF)];

/// נתונים שמועברים למסך האתגר אחרי סיום משחק (לחגיגה).
class DailyChallengeArgs {
  final DailyChallengeOutcome? outcome;
  const DailyChallengeArgs({this.outcome});
}

/// מסך האתגר היומי: לפני המשחק - פרטי האתגר, הרצף והפרס; אחרי המשחק -
/// הניקוד, דירוג מול החברים על אותו לוח, ושעון עד האתגר הבא.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  final DailyChallengeArgs? args;
  const DailyChallengeScreen({super.key, this.args});

  @override
  ConsumerState<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // ניסיון שננטש באמצע (האפליקציה נסגרה) נרשם כנוצל.
    if (widget.args?.outcome == null) {
      ref.read(playerProfileProvider.notifier).forfeitAbandonedDaily(DailyChallenge.forDate(DateTime.now()));
    }
    if (widget.args?.outcome != null) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _confetti.play();
        Haptics.success();
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await confirmStartDaily(context);
    if (ok && mounted) context.pushReplacement('/daily/play');
  }

  void _share(DailyChallenge challenge, int score, int streak) {
    showShareAchievementSheet(
      context,
      ShareAchievement(
        headline: 'אתגר יומי #${challenge.number}',
        subline: '$score נקודות${streak > 1 ? ' · 🔥 $streak ימים ברצף' : ''}',
        colors: kDailyGradient,
        badge: '📅',
        message:
            'השגתי $score נקודות באתגר היומי #${challenge.number} של "מצא ת׳מילה"! 📅\n'
            'אותו לוח לכולם - מי מנצח/ת אותי היום? 😎',
      ),
      contentType: 'daily_result',
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenge = DailyChallenge.forDate(_now);
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final played = profile?.playedDailyOn(challenge.dateKey) ?? false;
    final streak = profile == null
        ? 0
        : DailyChallenge.liveStreak(
            lastDate: profile.dailyChallengeDate,
            streak: profile.dailyChallengeStreak,
            today: _now,
          );
    final outcome = widget.args?.outcome;
    final tomorrow = DateTime(_now.year, _now.month, _now.day + 1);
    final left = tomorrow.difference(_now);
    String two(int v) => v.toString().padLeft(2, '0');
    final countdown = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';

    return GameScaffold(
      colors: kDailyGradient,
      header: GameHeader(
        title: 'האתגר היומי',
        subtitle: '#${challenge.number} · אותו לוח לכל השחקנים',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        trailing: played
            ? CandyIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'שיתוף',
                onPressed: () => _share(challenge, profile?.dailyChallengeScore ?? 0, streak),
              )
            : null,
      ),
      bottomBar: played
          ? CandyButton(
              label: 'למפת השלבים',
              icon: Icons.map_rounded,
              palette: CandyPalette.white,
              height: 56,
              fontSize: 18,
              onPressed: () => context.go('/campaign'),
            )
          : CandyButton(
              label: 'התחילו את האתגר!',
              icon: Icons.bolt_rounded,
              palette: CandyPalette.green,
              height: 64,
              fontSize: 22,
              onPressed: _start,
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.03, duration: 850.ms),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              shouldLoop: false,
              colors: const [AppColors.star, Colors.white, Color(0xFFFF6F91), Color(0xFF7CEB6E)],
            ),
          ),
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            children: [
              _StreakBanner(streak: streak, best: profile?.dailyChallengeBestStreak ?? 0, playedToday: played),
              const SizedBox(height: 14),
              if (!played)
                _IntroCard(challenge: challenge, streak: streak)
              else
                _ResultCard(
                  score: profile?.dailyChallengeScore ?? 0,
                  words: profile?.dailyChallengeWords ?? 0,
                  outcome: outcome,
                  countdown: countdown,
                ),
              const SizedBox(height: 14),
              _FriendsDailyBoard(dateKey: challenge.dateKey, played: played),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  final int best;
  final bool playedToday;

  const _StreakBanner({required this.streak, required this.best, required this.playedToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          Text(streak > 0 ? '🔥' : '🌱', style: const TextStyle(fontSize: 34))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.12, duration: 700.ms, curve: Curves.easeInOut),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak == 0 ? 'התחילו רצף חדש היום!' : '$streak ${streak == 1 ? 'יום' : 'ימים'} ברצף',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19),
                ),
                Text(
                  playedToday
                      ? 'נתראה מחר כדי להמשיך את הרצף${best > 1 ? ' · שיא: $best' : ''}'
                      : (streak > 0 ? 'שחקו היום כדי לא לשבור את הרצף!' : 'כל יום ברצף מוסיף בונוס מטבעות'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // שבעה "ימים" - נקודות שמתמלאות לפי הרצף.
          Row(
            children: [
              for (int i = 0; i < 7; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < (streak % 7 == 0 && streak > 0 ? 7 : streak % 7)
                        ? const Color(0xFFFFE27A)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}

class _IntroCard extends StatelessWidget {
  final DailyChallenge challenge;
  final int streak;
  const _IntroCard({required this.challenge, required this.streak});

  @override
  Widget build(BuildContext context) {
    final nextStreak = streak + 1;
    final maxCoins = DailyChallenge.coinsFor(score: 999, streak: nextStreak);
    Widget chip(IconData icon, String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF6B5E8F)),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Image.asset('assets/avatar/detective_explain.png', height: 110),
          const SizedBox(height: 6),
          const Text(
            'לוח אחד לכולם. ניסיון אחד ביום.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Color(0xFF2D2250)),
          ),
          const SizedBox(height: 4),
          const Text(
            'צברו כמה שיותר נקודות ותראו איפה אתם מול החברים',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF6B5E8F)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              chip(
                Icons.grid_view_rounded,
                '${challenge.gridSize}×${challenge.gridSize}',
                'לוח',
                const Color(0xFF3A7BFF),
              ),
              const SizedBox(width: 8),
              chip(Icons.timer_rounded, '${challenge.timeLimit.inSeconds}', 'שניות', const Color(0xFFFF7A45)),
              const SizedBox(width: 8),
              chip(Icons.paid_rounded, 'עד $maxCoins', 'מטבעות', const Color(0xFFE6A100)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack);
  }
}

class _ResultCard extends StatelessWidget {
  final int score;
  final int words;
  final DailyChallengeOutcome? outcome;
  final String countdown;

  const _ResultCard({required this.score, required this.words, required this.outcome, required this.countdown});

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text(
            o != null ? 'כל הכבוד!' : 'התוצאה שלך היום',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF6B5E8F)),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: o != null ? 0 : score, end: score),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '$v',
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Color(0xFFFF4F8B), height: 1.1),
            ),
          ),
          Text(
            'נקודות · $words מילים',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8A80A8)),
          ),
          if (o != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _Pill(icon: Icons.paid_rounded, text: '+${o.coins} מטבעות', color: const Color(0xFFE6A100)),
                _Pill(
                  icon: Icons.local_fire_department_rounded,
                  text: o.newBestStreak && o.streak > 1 ? 'שיא רצף חדש: ${o.streak}!' : 'רצף: ${o.streak}',
                  color: const Color(0xFFFF5A36),
                ),
              ],
            ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.7, 0.7), curve: Curves.elasticOut),
          ],
          const Divider(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFF8A80A8), size: 18),
              const SizedBox(width: 6),
              const Text(
                'האתגר הבא בעוד ',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A80A8)),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  countdown,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2D2250), fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

/// דירוג החברים באתגר של היום (מי ששיחק/ה) + "עוד לא שיחקו".
class _FriendsDailyBoard extends ConsumerWidget {
  final String dateKey;
  final bool played;
  const _FriendsDailyBoard({required this.dateKey, required this.played});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final social = ref.watch(socialRepositoryProvider);
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final photo = ref.watch(authStateProvider).valueOrNull?.photoUrl;
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];

    final rows = <({String name, String avatarId, String? photoUrl, int? score, bool isMe})>[
      (
        name: profile?.displayName ?? 'אני',
        avatarId: profile?.avatarId ?? 'detective',
        photoUrl: photo,
        score: played ? profile?.dailyChallengeScore : null,
        isMe: true,
      ),
      for (final f in friends)
        (
          name: f.profile.displayName,
          avatarId: f.profile.avatarId,
          photoUrl: f.profile.photoUrl,
          score: f.profile.dailyScoreOn(dateKey),
          isMe: false,
        ),
    ];
    rows.sort((a, b) {
      if (a.score == null && b.score == null) return a.isMe ? -1 : (b.isMe ? 1 : 0);
      if (a.score == null) return 1;
      if (b.score == null) return -1;
      return b.score!.compareTo(a.score!);
    });
    final playedCount = rows.where((r) => r.score != null).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB700)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'החברים היום',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2D2250)),
                ),
              ),
              if (friends.isNotEmpty)
                Text(
                  '$playedCount/${rows.length} שיחקו',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8A80A8)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!social.isAvailable || friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const Text(
                    'הוסיפו חברים כדי לראות מי ניצח היום על אותו לוח!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B5E8F)),
                  ),
                  const SizedBox(height: 10),
                  CandyButton(
                    label: 'לחברים שלי',
                    icon: Icons.people_alt_rounded,
                    palette: CandyPalette.purple,
                    height: 46,
                    fontSize: 16,
                    onPressed: () => context.push('/friends'),
                  ),
                ],
              ),
            )
          else
            for (int i = 0; i < rows.length; i++)
              _BoardRow(
                rank: !played || rows[i].score == null ? null : i + 1,
                name: rows[i].name,
                avatarId: rows[i].avatarId,
                photoUrl: rows[i].photoUrl,
                score: rows[i].score,
                isMe: rows[i].isMe,
                hideScore: !played && !rows[i].isMe,
              ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: 0.08, end: 0),
          if (!played && friends.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'הניקוד של החברים ייחשף אחרי שתשחקו 🤫',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A80A8)),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final int? rank;
  final String name;
  final String avatarId;
  final String? photoUrl;
  final int? score;
  final bool isMe;
  final bool hideScore;

  const _BoardRow({
    required this.rank,
    required this.name,
    required this.avatarId,
    required this.photoUrl,
    required this.score,
    required this.isMe,
    required this.hideScore,
  });

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉'];
    final r = rank;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFFF1F6) : null,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: const Color(0xFFFF8FC0), width: 1.5) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              r == null ? '–' : (r <= 3 ? medals[r - 1] : '$r'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF8A80A8)),
            ),
          ),
          const SizedBox(width: 6),
          AvatarWidget(avatarId: avatarId, photoUrl: photoUrl, size: 34, ring: false),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '$name (את/ה)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isMe ? FontWeight.w900 : FontWeight.w700, fontSize: 15),
            ),
          ),
          Text(
            score == null ? 'עוד לא שיחק/ה' : (hideScore ? '🔒 שיחק/ה' : '$score נק׳'),
            style: TextStyle(
              fontWeight: score == null ? FontWeight.w600 : FontWeight.w900,
              fontSize: score == null ? 12 : 15,
              color: score == null ? const Color(0xFFB0A8C8) : const Color(0xFF2D2250),
            ),
          ),
        ],
      ),
    );
  }
}
