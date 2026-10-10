import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

String _hex(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  return '#${[ch(c.r), ch(c.g), ch(c.b)].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
}

String? _last;

/// צובע את אזור השעה/הסוללה בדפדפן (theme-color) ואת רקע הדף בצבע העליון
/// של המסך הנוכחי - כך הפס העליון באייפון (Safari) "נבלע" ברקע של המסך.
void setBrowserTopColor(Color color) {
  final hex = _hex(color);
  if (hex == _last) return;
  _last = hex;
  try {
    final metas = web.document.querySelectorAll('meta[name="theme-color"]');
    if (metas.length == 0) {
      final meta = web.document.createElement('meta') as web.HTMLMetaElement;
      meta.name = 'theme-color';
      meta.content = hex;
      web.document.head?.append(meta);
    } else {
      for (var i = 0; i < metas.length; i++) {
        (metas.item(i) as web.HTMLMetaElement).content = hex;
      }
    }
    web.document.documentElement?.setAttribute('style', 'background-color: $hex');
    web.document.body?.style.backgroundColor = hex;
    // הפס הצמוד לראש המסך (ראו #top-tint ב-index.html) - זה מה ש-Safari
    // ב-iOS 26 משתמש בו לצבע אזור השעה.
    _replaceTopTint(hex);
  } catch (_) {
    // לא קריטי - רק קוסמטיקה של הדפדפן.
  }
}

/// האם לדפדפן יש תפריט שיתוף מובנה (Web Share API) - באייפון/אנדרואיד כן,
/// ברוב הדפדפנים במחשב לא.
bool browserCanShare() {
  try {
    return (web.window.navigator as JSObject).has('share');
  } catch (_) {
    return false;
  }
}

/// האם המסך מתחלף עכשיו בעקבות ניווט של הדפדפן (ראו __wbPop ב-index.html).
bool isBrowserHistoryNavigation() {
  try {
    final last = (globalContext['__wbPop'] as JSNumber?)?.toDartDouble ?? 0;
    if (last <= 0) return false;
    return web.window.performance.now() - last < 1200;
  } catch (_) {
    return false;
  }
}

/// מונה חסימות (כמה מסכי משחק פעילים) - ראו __wbGuard ב-index.html.
void setBrowserBackGuard(bool enabled) {
  try {
    final current = (globalContext['__wbGuard'] as JSNumber?)?.toDartInt ?? 0;
    final next = enabled ? current + 1 : (current - 1).clamp(0, 1 << 20);
    globalContext['__wbGuard'] = next.toJS;
  } catch (_) {}
}

void Function() onBrowserBackBlocked(void Function() callback) {
  final listener = ((web.Event _) => callback()).toJS;
  web.window.addEventListener('wb-back-blocked', listener);
  return () => web.window.removeEventListener('wb-back-blocked', listener);
}

/// Safari (iOS 26) דוגם את צבע אזור השעה מאלמנט fixed בראש הדף רק כשמבנה
/// האלמנטים הצמודים משתנה - שינוי צבע בלבד נקלט רק אחרי גלילה/גרירה. לכן
/// מכניסים פס *חדש* בצבע החדש, ומסירים את הישן בפריים הבא (בלי הבהוב).
void _replaceTopTint(String hex) {
  final body = web.document.body;
  if (body == null) return;
  final old = web.document.getElementById('top-tint');
  final fresh = web.document.createElement('div') as web.HTMLElement;
  fresh.id = 'top-tint';
  fresh.style.backgroundColor = hex;
  if (old != null) {
    old.id = 'top-tint-old';
    old.after(fresh);
    web.window.requestAnimationFrame(((JSNumber _) {
      old.remove();
    }).toJS);
  } else {
    body.append(fresh);
  }
}
