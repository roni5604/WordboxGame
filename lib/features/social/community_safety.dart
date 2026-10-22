import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/share/share_service.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import 'friends_screen.dart' show kFriendsGradient;
import 'services/social_repository.dart';

/// כללי הקהילה (EULA לתוכן משתמשים) ורשימת החסומים.
///
/// Apple (Guideline 1.2) דורשת באפליקציה עם תוכן משתמשים: הסכמה לתנאים
/// שאין בהם סובלנות לתוכן פוגעני, סינון, דיווח, חסימה, וטיפול בדיווחים תוך
/// 24 שעות. הסינון ב-InputRules, הדיווח והחסימה ב-SocialActions.
class CommunitySafety {
  CommunitySafety._();

  static const _acceptedKey = 'community_rules_accepted_v1';

  /// ההסכמה נשמרת לכל חשבון בנפרד: חשבון חדש (גם אחרי מחיקה או התנתקות)
  /// מתבקש להסכים שוב.
  static String _keyFor(String? uid) => uid == null ? _acceptedKey : '${_acceptedKey}_$uid';

  /// בודק/מבקש הסכמה לכללי הקהילה לפני שימוש ראשון בפיצ'רים החברתיים.
  /// מחזיר true אם אפשר להמשיך.
  static Future<bool> ensureAccepted(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    String? uid;
    try {
      uid = (await container.read(authStateProvider.future).timeout(const Duration(seconds: 3)))?.uid;
    } catch (_) {
      uid = container.read(authStateProvider).valueOrNull?.uid;
    }
    final key = _keyFor(uid);
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true) return true;
    } catch (_) {
      // בלי אחסון מקומי - מבקשים הסכמה בכל פעם.
    }
    if (!context.mounted) return false;
    final ok = await showGameDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GameDialog(
        title: 'כללי הקהילה',
        ribbon: CandyPalette.purple,
        message: 'כדי לשחק עם אחרים, מסכימים לכללים:\n'
            '• כינוי מכבד - בלי קללות, גזענות, הטרדה או תוכן מיני.\n'
            '• אין סובלנות לתוכן פוגעני או למשתמשים פוגעניים.\n'
            '• אפשר לדווח ולחסום כל משתמש/ת (⋮ ליד השם).\n'
            '• אנחנו בודקים כל דיווח תוך 24 שעות ומסירים תוכן או חשבון שמפר את הכללים.',
        body: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(
            onPressed: () => AppLinks.open(AppLinks.terms),
            child: const Text('לתנאי השימוש המלאים', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        actions: [
          CandyButton(
            label: 'מסכימ/ה',
            palette: CandyPalette.green,
            height: 54,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          CandyButton(
            label: 'לא עכשיו',
            palette: CandyPalette.white,
            height: 46,
            fontSize: 15,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await prefs?.setBool(key, true);
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// רשימת המשתמשים שחסמתי, עם ביטול חסימה.
  static Future<void> showBlockedUsers(BuildContext context) {
    return showGameDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final repo = ref.read(socialRepositoryProvider);
          return GameDialog(
            title: 'משתמשים חסומים',
            ribbon: CandyPalette.purple,
            onClose: () => Navigator.of(dialogContext).pop(),
            body: StreamBuilder<List<BlockedUser>>(
              stream: repo.watchBlockedUsers(),
              builder: (context, snap) {
                final list = snap.data ?? const <BlockedUser>[];
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('לא חסמתם אף אחד.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final u in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.block_rounded, color: Color(0xFFE5484D)),
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        trailing: TextButton(
                          onPressed: () => repo.unblockUser(u.uid).catchError((_) {}),
                          child: const Text('ביטול חסימה', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                );
              },
            ),
            actions: [
              CandyButton(
                label: 'סגירה',
                palette: CandyPalette.white,
                height: 48,
                fontSize: 16,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// עוטף מסך חברתי: בכניסה הראשונה מבקש הסכמה לכללי הקהילה, ואם לא מסכימים -
/// חוזר אחורה. המסך עצמו נבנה רק אחרי ההסכמה, כדי שכללי הקהילה יופיעו
/// ראשונים (לפני בחירת הכינוי במסך החברים, למשל).
class CommunityRulesGate extends StatefulWidget {
  final Widget child;
  const CommunityRulesGate({super.key, required this.child});

  @override
  State<CommunityRulesGate> createState() => _CommunityRulesGateState();
}

class _CommunityRulesGateState extends State<CommunityRulesGate> {
  /// חשבונות שכבר הסכימו בהרצה הנוכחית - נכנסים מיד, בלי מסך ביניים.
  static final _acceptedThisRun = <String?>{};

  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    final uid = ProviderScope.containerOf(context, listen: false).read(authStateProvider).valueOrNull?.uid;
    if (uid != null && _acceptedThisRun.contains(uid)) {
      _accepted = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await CommunitySafety.ensureAccepted(context);
      if (!mounted) return;
      if (ok) {
        if (uid != null) _acceptedThisRun.add(uid);
        setState(() => _accepted = true);
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: kFriendsGradient,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
