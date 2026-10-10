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
