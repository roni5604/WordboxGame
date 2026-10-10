import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/share/share_service.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/pressable.dart';

/// הישג לשיתוף: מה שמופיע על "כרטיס ההישג" (תמונה) ובטקסט המצורף.
class ShareAchievement {
  /// כותרת גדולה על הכרטיס, למשל "עברתי את שלב 12!".
  final String headline;

  /// שורת משנה, למשל "64 נקודות · 11 מילים".
  final String subline;

  /// 0-3 כוכבים (null = לא מציגים כוכבים, למשל בניצחון בתחרות).
  final int? stars;

  /// צבעי הגרדיאנט של הכרטיס (בדרך כלל צבעי העולם של השלב).
  final List<Color> colors;

  /// אמוג'י/סמל גדול בפינה (🏆 לניצחון, 🔓 לעולם חדש וכו').
  final String badge;

  /// הטקסט שנשלח לוואטסאפ / מצורף לשיתוף המערכת. הקישור למשחק נוסף
  /// אוטומטית בסוף.
  final String message;

  const ShareAchievement({
    required this.headline,
    required this.subline,
    required this.colors,
    required this.message,
    this.stars,
    this.badge = '⭐',
  });

  String get messageWithLink => '$message\n${AppLinks.webBase}';

  /// ניצחון בתחרות (מול המחשב או מול חברים).
  factory ShareAchievement.raceWin({
    required int score,
    required List<String> opponents,
    required bool vsFriends,
    String? seriesLabel,
  }) {
    final who = opponents.isEmpty
        ? ''
        : opponents.length == 1
        ? opponents.first
        : '${opponents.sublist(0, opponents.length - 1).join(', ')} ו${opponents.last}';
    return ShareAchievement(
      headline: vsFriends ? 'ניצחתי בתחרות!' : 'ניצחתי את המחשב!',
      subline: seriesLabel ?? '$score נקודות${who.isEmpty ? '' : ' · מול $who'}',
      colors: const [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
      badge: '🏆',
      message: vsFriends
          ? 'ניצחתי ${who.isEmpty ? 'בתחרות' : 'את $who'} ב"מצא ת׳מילה" עם $score נקודות! 🏆\nמי הבא/ה בתור? 😎'
          : 'ניצחתי בתחרות מול המחשב ב"מצא ת׳מילה" עם $score נקודות! 🏆\nבואו לנסות לנצח אותי 😎',
    );
  }

  /// שלב שהושלם במפת השלבים.
  factory ShareAchievement.level({
    required int levelNumber,
    required int stars,
    required int score,
    required int words,
    required List<Color> colors,
    bool newWorld = false,
    String? worldTitle,
  }) {
    final starsText = '⭐' * stars;
    return ShareAchievement(
      headline: newWorld ? 'פתחתי עולם חדש!' : 'עברתי את שלב $levelNumber!',
      subline: newWorld && worldTitle != null ? '$worldTitle · $score נקודות' : '$score נקודות · $words מילים',
      stars: stars,
      colors: colors,
      badge: newWorld ? '🔓' : (stars >= 3 ? '🏆' : '⭐'),
      message: newWorld
          ? 'פתחתי עולם חדש ב"מצא ת׳מילה"${worldTitle == null ? '' : ' - $worldTitle'}! 🔓 $starsText\n'
                'מי מצליח/ה להגיע אליי? 😎'
          : 'עברתי את שלב $levelNumber ב"מצא ת׳מילה" עם $score נקודות! $starsText\n'
                'בואו לנסות לנצח אותי 😎',
    );
  }
}

/// פותח את חלון השיתוף: תצוגה מקדימה של כרטיס ההישג, ושלושה כפתורים
/// גדולים - פייסבוק, וואטסאפ, ו"עוד" (גיליון השיתוף של המערכת, עם התמונה).
Future<void> showShareAchievementSheet(BuildContext context, ShareAchievement achievement) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => _ShareSheet(achievement: achievement),
  );
}

class _ShareSheet extends StatefulWidget {
  final ShareAchievement achievement;
  const _ShareSheet({required this.achievement});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (e) {
      debugPrint('achievement capture failed: $e');
      return null;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _facebook() => _run(() async {
    // פייסבוק לא מאפשר יותר למלא טקסט מראש בפוסט, אז מעתיקים אותו ללוח
    // כדי שיהיה אפשר פשוט להדביק.
    await Clipboard.setData(ClipboardData(text: widget.achievement.message));
    if (mounted) {
      GameToast.show(context, message: 'הטקסט הועתק - הדביקו אותו בפוסט 📋', icon: Icons.content_paste_rounded);
    }
    await ShareService.facebook();
  });

  Future<void> _whatsApp() => _run(() async {
    await ShareService.whatsApp(widget.achievement.messageWithLink);
  });

  Future<void> _more() => _run(() async {
    final png = await _capture();
    if (!mounted) return;
    await ShareService.system(context, text: widget.achievement.messageWithLink, imagePng: png, subject: 'מצא ת׳מילה');
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'שתפו את ההישג',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2D2250)),
            ),
            const SizedBox(height: 4),
            const Text(
              'תנו לחברים לראות - ותזמינו אותם לנסות לנצח אתכם',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B6385)),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _cardKey,
              child: AchievementCard(achievement: widget.achievement),
            ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ShareTarget(
                    label: 'פייסבוק',
                    color: const Color(0xFF1877F2),
                    icon: const Text(
                      'f',
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                    onTap: _busy ? null : _facebook,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShareTarget(
                    label: 'וואטסאפ',
                    color: const Color(0xFF25D366),
                    icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 28),
                    onTap: _busy ? null : _whatsApp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShareTarget(
                    label: 'עוד...',
                    color: const Color(0xFF7B3FF2),
                    icon: _busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Icon(Icons.ios_share_rounded, color: Colors.white, size: 28),
                    onTap: _busy ? null : _more,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 120.ms, duration: 250.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  final String label;
  final Color color;
  final Widget icon;
  final VoidCallback? onTap;

  const _ShareTarget({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'שיתוף ב$label',
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: icon,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2D2250)),
          ),
        ],
      ),
    );
  }
}

/// "כרטיס ההישג" - ריבוע מעוצב שנשמר כתמונה ומצורף לשיתוף.
class AchievementCard extends StatelessWidget {
  final ShareAchievement achievement;
  final double size;

  const AchievementCard({super.key, required this.achievement, this.size = 300});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final scale = size / 300;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28 * scale),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: a.colors),
          ),
          child: Stack(
            children: [
              // "בועות" דקורטיביות ברקע.
              for (final (x, y, r, o) in const [
                (0.08, 0.12, 48.0, 0.14),
                (0.85, 0.22, 30.0, 0.12),
                (0.75, 0.82, 60.0, 0.10),
                (0.15, 0.78, 22.0, 0.16),
              ])
                Positioned(
                  left: x * size - r * scale,
                  top: y * size - r * scale,
                  child: Container(
                    width: r * 2 * scale,
                    height: r * 2 * scale,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: o),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(20 * scale),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10 * scale),
                          child: Image.asset('assets/icon/app_icon.png', width: 34 * scale, height: 34 * scale),
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          'מצא ת׳מילה',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17 * scale),
                        ),
                        const Spacer(),
                        Text(a.badge, style: TextStyle(fontSize: 30 * scale)),
                      ],
                    ),
                    Expanded(
                      // התוכן המרכזי מתכווץ בעדינות אם הכותרת ארוכה (שתי
                      // שורות) - הכרטיס תמיד נשאר ריבוע שלם.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 260 * scale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/avatar/detective_celebrate.png', height: 92 * scale),
                              SizedBox(height: 6 * scale),
                              Text(
                                a.headline,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 27 * scale,
                                  height: 1.1,
                                  shadows: const [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                                ),
                              ),
                              if (a.stars != null) ...[
                                SizedBox(height: 4 * scale),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0; i < 3; i++)
                                      Icon(
                                        Icons.star_rounded,
                                        size: 34 * scale,
                                        color: i < a.stars!
                                            ? const Color(0xFFFFD233)
                                            : Colors.white.withValues(alpha: 0.35),
                                      ),
                                  ],
                                ),
                              ],
                              SizedBox(height: 4 * scale),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 5 * scale),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20 * scale),
                                ),
                                child: Text(
                                  a.subline,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14 * scale,
                                    color: const Color(0xFF2D2250),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'משחקו של רוני מיכאלי',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 10 * scale,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
