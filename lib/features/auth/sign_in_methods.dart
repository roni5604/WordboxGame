import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/config/app_config.dart';

/// התחברות עם Apple: ב-iOS/macOS, ובאתר רק אחרי הגדרת Services ID ב-Firebase
/// (ראו AppConfig). באנדרואיד לא מוצגת.
bool appleSignInAvailable() => kIsWeb ? AppConfig.appleLoginWeb : (Platform.isIOS || Platform.isMacOS);

/// לטקסטים כמו "הרשמו בחינם עם ..." - רק שיטות שבאמת מופיעות במסך ההתחברות.
String signInMethodsText() => appleSignInAvailable() ? 'Google, Apple או מייל' : 'Google או מייל';
