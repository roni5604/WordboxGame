import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';

/// מעברים בין חשבונות (התנתקות, החלפת חשבון, מחיקה) - במקום אחד, כדי שבכל
/// מסלול הנתונים של החשבון הקודם לא יישארו על המסך ולא יישמרו לחשבון החדש.
class AccountFlows {
  AccountFlows._();

  /// ממתין עד שמצב ההתחברות במשחק מראה את [uid] (האירוע מ-Firebase מגיע
  /// מעט אחרי שהפעולה עצמה מסתיימת), ואז טוען מחדש את הפרופיל של החשבון.
  static Future<void> reloadFor(WidgetRef ref, String uid) async {
    for (var i = 0; i < 40; i++) {
      if (ref.read(authStateProvider).valueOrNull?.uid == uid) break;
      await Future<void>.delayed(const Duration(milliseconds: 75));
    }
    ref.invalidate(playerProfileProvider);
    await ref.read(playerProfileProvider.notifier).ensureLoaded();
  }

  /// התנתקות: יוצאים מהחשבון, נכנסים כאורח/ת חדש/ה, וחוזרים למסך הפתיחה
  /// (מסך ההתחברות הראשוני), בלי שום נתון של החשבון הקודם.
  static Future<void> signOutToStart(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    final guest = await repo.signInAsGuest();
    await reloadFor(ref, guest.uid);
    if (context.mounted) context.go('/');
  }
}
