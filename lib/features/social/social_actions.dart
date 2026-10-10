import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      '/multiplayer/online/create?invite=${Uri.encodeComponent(uid)}&inviteName=${Uri.encodeComponent(name)}',
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
    await ref.read(playerProfileProvider.notifier).setDisplayName(name);
    return name;
  }

  static String friendlyError(Object e) {
    if (e is SocialException) return e.message;
    final text = e.toString();
    if (text.contains('permission-denied') || text.contains('PERMISSION_DENIED')) {
      return 'שרת החברים עדיין מתעדכן - נסו שוב בעוד כמה דקות.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'אין חיבור לאינטרנט כרגע.';
    }
    return 'משהו השתבש, נסו שוב.';
  }
}
