import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// קורא את env(safe-area-inset-*) מאלמנט המדידה שב-index.html.
///
/// בדפדפני אפל יש גם פס צבע גלוי בראש הדף (#top-tint, ראו index.html) -
/// ממנו Safari לוקח את צבע אזור השעה. התוכן חייב להתחיל מתחתיו, אז האזור
/// הבטוח העליון הוא לפחות גובה הפס.
EdgeInsets readSafeAreaInsets() {
  try {
    final probe = web.document.getElementById('safe-area-probe');
    double px(String value) => double.tryParse(value.replaceAll('px', '').trim()) ?? 0;
    var insets = EdgeInsets.zero;
    if (probe != null) {
      final style = web.window.getComputedStyle(probe);
      insets = EdgeInsets.fromLTRB(
        px(style.paddingLeft),
        px(style.paddingTop),
        px(style.paddingRight),
        px(style.paddingBottom),
      );
    }
    final tint = web.document.getElementById('top-tint');
    if (tint != null) {
      // display:none (לא דפדפן אפל) -> גובה 0.
      final tintHeight = tint.getBoundingClientRect().height;
      if (tintHeight > insets.top) insets = insets.copyWith(top: tintHeight);
    }
    return insets;
  } catch (_) {
    return EdgeInsets.zero;
  }
}
