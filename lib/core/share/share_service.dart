import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/browser_chrome_stub.dart' if (dart.library.js_interop) '../platform/browser_chrome_web.dart'
    as browser;
import '../ui/game_dialog.dart';

/// קישורים ציבוריים למשחק. גרסת האתר מתארחת ב-GitHub Pages, וכל קישור
/// הזמנה פותח אותה ישירות - חבר/ה בלי האפליקציה יכול/ה לשחק מיד בדפדפן.
class AppLinks {
  AppLinks._();

  static const webBase = 'https://roni5604.github.io/WordboxGame/';

  /// קישור הצטרפות ישיר לחדר (נפתח במסך ההצטרפות עם הקוד מוכן).
  static String joinRoom(String roomCode) => '$webBase#/join/$roomCode';

  static String friends() => '$webBase#/friends';
}

/// שיתוף לרשתות: וואטסאפ, פייסבוק, וגיליון השיתוף של המערכת.
class ShareService {
  ShareService._();

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('share launch failed: $e');
      return false;
    }
  }

  /// פותח את וואטסאפ עם הודעה מוכנה (המשתמש/ת בוחר/ת למי לשלוח).
  static Future<bool> whatsApp(String text) =>
      _open(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'));

  /// פותח את חלון השיתוף של פייסבוק עם קישור למשחק והאשטאג.
  /// (פייסבוק לא מאפשר יותר למלא טקסט מראש - הכותרת והתמונה נלקחות
  /// מתגיות ה-Open Graph של האתר, ראו web/index.html.)
  static Future<bool> facebook({String url = AppLinks.webBase, String hashtag = '#מצא_תמילה'}) {
    final uri = Uri.https('www.facebook.com', '/sharer/sharer.php', {
      'u': url,
      'hashtag': hashtag,
    });
    return _open(uri);
  }

  /// גיליון השיתוף של המערכת (באייפון/אנדרואיד: כל האפליקציות המותקנות,
  /// כולל פייסבוק ואינסטגרם; באתר: Web Share API או העתקה).
  static Future<void> system(
    BuildContext context, {
    required String text,
    Uint8List? imagePng,
    String? subject,
  }) async {
    // דפדפן בלי תפריט שיתוף (בעיקר במחשב): share_plus היה פותח חלון מייל.
    // במקום זה מעתיקים את הטקסט ומציגים הודעה.
    if (kIsWeb && !browser.browserCanShare()) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        GameToast.show(context, message: 'ההזמנה הועתקה - הדביקו אותה בוואטסאפ או בהודעה 📋', icon: Icons.content_paste_rounded);
      }
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      if (imagePng != null) {
        await Share.shareXFiles(
          [XFile.fromData(imagePng, mimeType: 'image/png', name: 'wordbox.png')],
          text: text,
          subject: subject,
          sharePositionOrigin: origin,
        );
      } else {
        await Share.share(text, subject: subject, sharePositionOrigin: origin);
      }
    } catch (e) {
      debugPrint('system share failed: $e');
    }
  }
}
