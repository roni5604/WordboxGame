import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool? _isIOS;

bool get _ios {
  return _isIOS ??= () {
    final ua = web.window.navigator.userAgent;
    return RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
        (web.window.navigator.platform == 'MacIntel' && web.window.navigator.maxTouchPoints > 1);
  }();
}

/// רטט באתר: באנדרואיד - navigator.vibrate (תבנית של מילישניות רטט/הפסקה).
/// באייפון אין vibrate, אבל מ-iOS 18 Safari מפעיל "טיק" הפטי כשמפעילים
/// <input type="checkbox" switch> - משתמשים בזה לכל פולס בתבנית.
/// מחזיר false אם אין שום דרך לרטוט בדפדפן הזה.
bool webVibrate(List<int> pattern) {
  if (pattern.isEmpty) return false;
  try {
    if (_ios) {
      var delay = 0;
      for (var i = 0; i < pattern.length; i += 2) {
        if (delay == 0) {
          _iosTick();
        } else {
          web.window.setTimeout((() => _iosTick()).toJS, delay.toJS);
        }
        delay += pattern[i] + (i + 1 < pattern.length ? pattern[i + 1] : 0);
      }
      return true;
    }
    final nav = web.window.navigator as JSObject;
    if (!nav.has('vibrate')) return false;
    nav.callMethod('vibrate'.toJS, pattern.map((e) => e.toJS).toList().toJS);
    return true;
  } catch (_) {
    return false;
  }
}

void _iosTick() {
  try {
    final body = web.document.body;
    if (body == null) return;
    final label = web.document.createElement('label') as web.HTMLLabelElement;
    label.ariaHidden = 'true';
    label.style.cssText = 'position:fixed;left:-9999px;top:0;width:1px;height:1px;opacity:0;pointer-events:none;';
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'checkbox';
    input.setAttribute('switch', '');
    label.append(input);
    body.append(label);
    label.click();
    label.remove();
  } catch (_) {}
}
