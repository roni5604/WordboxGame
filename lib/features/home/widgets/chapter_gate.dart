import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/candy_button.dart';
import '../../../core/ui/game_dialog.dart';
import '../../../data/models/player_profile.dart';
import '../../../game_engine/chapters.dart';
import '../../../providers/player_profile_provider.dart';
import '../../../providers/sound_provider.dart';

/// שער פרק סגור (ראו [CampaignChapters]): כמה כוכבים יש ומה חסר, אילו
/// שלבים הכי כדאי לשפר, וכפתור פתיחה במטבעות. מוצג במסך פתיחת השלב
/// ובחלון שנפתח מהמפה.
class ChapterGatePanel extends ConsumerStatefulWidget {
  final int chapter;

  /// נקרא אחרי שהפרק נפתח במטבעות.
  final VoidCallback? onUnlocked;

  /// נקרא לפני מעבר לשלב אחר לשיפור כוכבים (למשל לסגור חלון).
  final VoidCallback? onNavigate;

  const ChapterGatePanel({super.key, required this.chapter, this.onUnlocked, this.onNavigate});

  @override
  ConsumerState<ChapterGatePanel> createState() => _ChapterGatePanelState();
}

class _ChapterGatePanelState extends ConsumerState<ChapterGatePanel> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile != null) {
      ref
          .read(analyticsProvider)
          .chapterGateShown(chapter: widget.chapter, missingStars: profile.missingStarsFor(widget.chapter));
    }
  }

  /// שלבים שעברו בפחות מ-3 כוכבים - הכי מעט כוכבים קודם, ובתוך זה הכי
  /// מוקדם (לוח קטן יותר, קל יותר להשלים).
  static List<(int level, int stars)> _levelsToImprove(PlayerProfile profile, int beforeLevel) {
    final list = <(int, int)>[
      for (var l = 1; l < beforeLevel; l++)
        if (profile.progressFor(l).stars < 3 && profile.isLevelUnlocked(l)) (l, profile.progressFor(l).stars),
    ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
    return list.take(3).toList();
  }

  Future<void> _unlock(PlayerProfile profile, int cost) async {
    if (_busy) return;
    if (profile.coins < cost) {
      Haptics.error();
      ref.read(soundServiceProvider).playError();
      GameToast.show(
        context,
        message: 'חסרים ${cost - profile.coins} מטבעות',
        icon: Icons.paid_rounded,
        color: AppColors.error,
        actionLabel: 'לחנות',
        onTap: () {
          widget.onNavigate?.call();
          context.push('/store?from=chapter_gate');
        },
      );
      return;
    }
    setState(() => _busy = true);
    final missing = profile.missingStarsFor(widget.chapter);
    final paid = await ref.read(playerProfileProvider.notifier).unlockChapter(widget.chapter);
    if (!mounted) return;
    setState(() => _busy = false);
    if (paid == null) return;
    if (paid > 0) {
      ref.read(analyticsProvider)
        ..spendVirtualCurrency(currency: 'coins', value: paid, itemName: 'chapter_unlock_${widget.chapter}')
        ..chapterUnlocked(chapter: widget.chapter, cost: paid, missingStars: missing);
    }
    Haptics.success();
    ref.read(soundServiceProvider).playCoin();
    widget.onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();
    final chapter = widget.chapter;
    final required = CampaignChapters.requiredStars(chapter);
    final have = profile.totalStars;
    final missing = profile.missingStarsFor(chapter);
    final cost = CampaignChapters.unlockCost(chapter: chapter, missingStars: missing);
    final firstLevel = CampaignChapters.firstLevelOf(chapter);
    final toImprove = _levelsToImprove(profile, firstLevel);
    final progress = required <= 0 ? 1.0 : (have / required).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFFB57BFF), Color(0xFF7B3FF2)]),
            boxShadow: [BoxShadow(color: Color(0x557B3FF2), blurRadius: 16)],
          ),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
        ).animate().scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 700.ms),
        const SizedBox(height: 10),
        Text(
          'כדי להיכנס לפרק $chapter צריך $required כוכבים',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textDark),
        ),
        const SizedBox(height: 12),
        _StarsBar(have: have, required: required, progress: progress),
        const SizedBox(height: 6),
        Text(
          missing == 1 ? 'חסר כוכב אחד' : 'חסרים $missing כוכבים',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF7B3FF2)),
        ),
        if (toImprove.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'שפרו כוכבים בשלבים קודמים:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B5E8F)),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (level, stars) in toImprove)
                _ImproveChip(
                  level: level,
                  stars: stars,
                  onTap: () {
                    widget.onNavigate?.call();
                    context.push('/level/$level/intro');
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        CandyButton(
          label: 'פתחו עכשיו · $cost',
          icon: Icons.paid_rounded,
          palette: CandyPalette.gold,
          height: 56,
          fontSize: 19,
          onPressed: _busy ? null : () => _unlock(profile, cost),
        ),
        const SizedBox(height: 6),
        Text(
          'יש לכם ${profile.coins} מטבעות',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A80A8)),
        ),
      ],
    );
  }
}

class _StarsBar extends StatelessWidget {
  final int have;
  final int required;
  final double progress;

  const _StarsBar({required this.have, required this.required, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBFA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0D6F5), width: 2),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFFB700)]),
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFF5A3300), size: 18),
                const SizedBox(width: 4),
                Text(
                  '$have / $required',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5A3300)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImproveChip extends StatelessWidget {
  final int level;
  final int stars;
  final VoidCallback onTap;

  const _ImproveChip({required this.level, required this.stars, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF5E8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'שלב $level',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 6),
              for (var i = 0; i < 3; i++)
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: i < stars ? AppColors.star : const Color(0xFFE0D6C8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// חלון שער-פרק מהמפה. מחזיר true אם הפרק נפתח.
Future<bool> showChapterGateDialog(BuildContext context, int chapter) async {
  final result = await showGameDialog<bool>(
    context: context,
    builder: (dialogContext) => GameDialog(
      title: 'פרק $chapter',
      ribbon: CandyPalette.purple,
      onClose: () => Navigator.of(dialogContext).pop(false),
      body: ChapterGatePanel(
        chapter: chapter,
        onUnlocked: () => Navigator.of(dialogContext).pop(true),
        onNavigate: () => Navigator.of(dialogContext).pop(false),
      ),
    ),
  );
  return result ?? false;
}
