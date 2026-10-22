import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/security/input_rules.dart';
import '../../core/share/share_service.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_dialog.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/social_provider.dart';
import 'services/social_repository.dart';

/// פעולות חברתיות משותפות לכמה מסכים (רשימת חברים, לובי, מסך תוצאות).
class SocialActions {
  SocialActions._();

  static Future<void> sendFriendRequest(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String name,
  }) async {
    try {
      final instant = await ref.read(socialRepositoryProvider).sendFriendRequest(uid, toName: name);
      if (!context.mounted) return;
      GameToast.show(
        context,
        message: instant ? 'אתם עכשיו חברים עם $name! 🎉' : 'בקשת חברות נשלחה ל$name 💌',
        icon: instant ? Icons.celebration_rounded : Icons.send_rounded,
        color: instant ? const Color(0xFF33C24D) : const Color(0xFF7B3FF2),
      );
    } catch (e) {
      if (!context.mounted) return;
      GameToast.show(context, message: friendlyError(e), icon: Icons.info_rounded, color: const Color(0xFFFF7A45));
    }
  }

  /// "הזמנה למשחק" לחבר/ה: יוצרים חדר (עם ההגדרות שבוחרים) ושולחים
  /// הזמנה אוטומטית ברגע שהחדר נוצר.
  static void inviteToNewRoom(BuildContext context, {required String uid, required String name}) {
    context.push(
      '/multiplayer/online/create',
      extra: {'inviteUid': uid, 'inviteName': name},
    );
  }

  static Future<void> shareMyFriendCode(BuildContext context, WidgetRef ref, {bool whatsApp = true}) async {
    final repo = ref.read(socialRepositoryProvider);
    try {
      final code = await repo.myFriendCode();
      final name = ref.read(playerProfileProvider).valueOrNull?.displayName ?? '';
      final text = 'בואו נהיה חברים ב"מצא ת׳מילה"! 🔤\n'
          'הקוד שלי: $code\n'
          '${name.isNotEmpty ? '($name)\n' : ''}'
          'הכנסו למסך החברים ← "הוספת חבר" והקלידו את הקוד:\n${AppLinks.friends()}';
      AnalyticsService.instance.share(method: whatsApp ? 'whatsapp' : 'system', contentType: 'friend_code');
      if (whatsApp) {
        final ok = await ShareService.whatsApp(text);
        if (!ok && context.mounted) await ShareService.system(context, text: text);
      } else if (context.mounted) {
        await ShareService.system(context, text: text);
      }
    } catch (e) {
      if (context.mounted) {
        GameToast.show(context, message: friendlyError(e), icon: Icons.info_rounded, color: const Color(0xFFFF7A45));
      }
    }
  }

  static Future<void> copyFriendCode(BuildContext context, String code) async {
    AnalyticsService.instance.share(method: 'copy_code', contentType: 'friend_code');
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      GameToast.show(context, message: 'הקוד $code הועתק 📋', icon: Icons.copy_rounded);
    }
  }

  /// מבקש כינוי כשעדיין אין (כדי שחברים יזהו אותך). מחזיר את השם שנשמר.
  static Future<String?> editDisplayName(BuildContext context, WidgetRef ref) async {
    final current = ref.read(playerProfileProvider).valueOrNull?.displayName ?? '';
    final controller = TextEditingController(text: current == 'שחקן/ית' ? '' : current);
    final result = await showGameDialog<String>(
      context: context,
      builder: (dialogContext) => GameDialog(
        title: 'איך יקראו לך?',
        ribbon: CandyPalette.orange,
        message: 'השם שחברים יראו ברשימת החברים, בדירוג ובחדרי המשחק.',
        body: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 16,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'כינוי',
              filled: true,
              fillColor: const Color(0xFFF6F2FF),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
          ),
        ),
        actions: [
          CandyButton(
            label: 'שמירה',
            palette: CandyPalette.green,
            height: 54,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
    final name = result?.trim();
    if (name == null || name.isEmpty) return null;
    if (InputRules.isOffensiveName(name)) {
      if (context.mounted) {
        GameToast.show(context, message: 'הכינוי הזה לא מתאים. בחרו כינוי אחר 🙏', icon: Icons.block_rounded, color: const Color(0xFFE5484D));
      }
      return null;
    }
    await ref.read(playerProfileProvider.notifier).setDisplayName(name);
    return name;
  }

  // ---------------------------------------------------------------------------
  // בטיחות: דיווח וחסימה (Guideline 1.2 של Apple לתוכן משתמשים)
  // ---------------------------------------------------------------------------

  /// תפריט פעולות על משתמש/ת אחר/ת: דיווח, חסימה, ו(אם חבר/ה) הסרה.
  static Future<void> showUserSafetyMenu(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String name,
    String source = '',
    bool isFriend = false,
  }) async {
    final choice = await showGameDialog<String>(
      context: context,
      builder: (dialogContext) => GameDialog(
        title: name,
        ribbon: CandyPalette.purple,
        message: 'מה תרצו לעשות?',
        onClose: () => Navigator.of(dialogContext).pop(),
        actions: [
          CandyButton(
            label: 'דיווח על משתמש/ת',
            icon: Icons.flag_rounded,
            palette: CandyPalette.orange,
            height: 52,
            fontSize: 16,
            onPressed: () => Navigator.of(dialogContext).pop('report'),
          ),
          CandyButton(
            label: 'חסימה',
            icon: Icons.block_rounded,
            palette: CandyPalette.red,
            height: 52,
            fontSize: 16,
            onPressed: () => Navigator.of(dialogContext).pop('block'),
          ),
          if (isFriend)
            CandyButton(
              label: 'הסרה מהחברים',
              palette: CandyPalette.white,
              height: 48,
              fontSize: 15,
              onPressed: () => Navigator.of(dialogContext).pop('remove'),
            ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'report':
        await reportUser(context, ref, uid: uid, name: name, source: source);
      case 'block':
        await blockUser(context, ref, uid: uid, name: name);
      case 'remove':
        final ok = await showConfirmDialog(
          context,
          title: 'הסרת חבר',
          message: 'להסיר את $name מרשימת החברים?',
          confirmLabel: 'הסרה',
          confirmPalette: CandyPalette.red,
        );
        if (ok) await ref.read(socialRepositoryProvider).removeFriend(uid).catchError((_) {});
    }
  }

  /// דיווח: בוחרים סיבה, שולחים, ומציעים לחסום מיד.
  static Future<void> reportUser(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String name,
    String source = '',
  }) async {
    final reason = await showGameDialog<ReportReason>(
      context: context,
      builder: (dialogContext) => GameDialog(
        title: 'דיווח על $name',
        ribbon: CandyPalette.orange,
        message: 'מה הבעיה? הצוות שלנו בודק כל דיווח תוך 24 שעות.',
        onClose: () => Navigator.of(dialogContext).pop(),
        actions: [
          for (final r in ReportReason.values)
            CandyButton(
              label: r.labelHe,
              palette: CandyPalette.white,
              height: 46,
              fontSize: 15,
              onPressed: () => Navigator.of(dialogContext).pop(r),
            ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(socialRepositoryProvider).reportUser(uid: uid, name: name, reason: reason, context: source);
      AnalyticsService.instance.userReport(reason: reason.code);
    } catch (e) {
      if (context.mounted) {
        GameToast.show(context, message: friendlyError(e), icon: Icons.info_rounded, color: const Color(0xFFFF7A45));
      }
      return;
    }
    if (!context.mounted) return;
    final block = await showConfirmDialog(
      context,
      title: 'תודה על הדיווח 🙏',
      message: 'נבדוק אותו תוך 24 שעות. לחסום גם את $name? משתמש/ת חסומ/ה לא יוכל/תוכל לשלוח לכם בקשות או הזמנות.',
      confirmLabel: 'חסימה',
      cancelLabel: 'לא עכשיו',
      confirmPalette: CandyPalette.red,
    );
    if (block && context.mounted) await blockUser(context, ref, uid: uid, name: name, confirm: false);
  }

  /// חסימה (עם אישור): מסירה מהחברים, מוחקת בקשות והזמנות, ומונעת חדשות.
  static Future<void> blockUser(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String name,
    bool confirm = true,
  }) async {
    if (confirm) {
      final ok = await showConfirmDialog(
        context,
        title: 'לחסום את $name?',
        message: 'החסימה תסיר את $name מהחברים, ולא יוכל/תוכל לשלוח לכם בקשות חברות או הזמנות למשחק. '
            'אפשר לבטל בכל עת: הגדרות ← משתמשים חסומים.',
        confirmLabel: 'חסימה',
        confirmPalette: CandyPalette.red,
      );
      if (!ok || !context.mounted) return;
    }
    try {
      await ref.read(socialRepositoryProvider).blockUser(uid, name: name);
      AnalyticsService.instance.userBlock();
      if (context.mounted) {
        GameToast.show(context, message: '$name נחסמ/ה', icon: Icons.block_rounded, color: const Color(0xFF7B3FF2));
      }
    } catch (e) {
      if (context.mounted) {
        GameToast.show(context, message: friendlyError(e), icon: Icons.info_rounded, color: const Color(0xFFFF7A45));
      }
    }
  }

  static String friendlyError(Object e) {
    if (e is SocialException) return e.message;
    final text = e.toString();
    if (text.contains('permission-denied') || text.contains('PERMISSION_DENIED')) {
      return 'הפעולה לא הצליחה. נסו שוב בעוד רגע.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'אין חיבור לאינטרנט כרגע.';
    }
    return 'משהו השתבש, נסו שוב.';
  }
}
