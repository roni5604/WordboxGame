import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// קורא את env(safe-area-inset-*) מאלמנט המדידה שב-index.html.
EdgeInsets readSafeAreaInsets() {
  try {
    final probe = web.document.getElementById('safe-area-probe');
    if (probe == null) return EdgeInsets.zero;
    final style = web.window.getComputedStyle(probe);
    double px(String value) => double.tryParse(value.replaceAll('px', '').trim()) ?? 0;
    return EdgeInsets.fromLTRB(
      px(style.paddingLeft),
      px(style.paddingTop),
      px(style.paddingRight),
      px(style.paddingBottom),
    );
  } catch (_) {
    return EdgeInsets.zero;
  }
}
