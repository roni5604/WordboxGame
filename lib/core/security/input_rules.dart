/// כללי קלט משותפים: ניקוי שמות תצוגה ובדיקת קודים שמגיעים מבחוץ
/// (קישורים, הזמנות, שדות טקסט) לפני שהם נשמרים או נכנסים לנתיב ב-Firestore.
class InputRules {
  InputRules._();

  /// אורך שם תצוגה מקסימלי בכל מקום במשחק (חוקי Firestore מאפשרים עד 40).
  static const int maxDisplayName = 18;

  static final RegExp _roomCode = RegExp(r'^\d{5}$');

  // תווי בקרה ותווי כיווניות (RLO/LRO/isolates) - אפשר להשתמש בהם כדי
  // "להפוך" טקסט ולהתחזות לשם אחר, במיוחד בממשק מימין לשמאל.
  static final RegExp _unsafeChars = RegExp(
    r'[\u0000-\u001F\u007F\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  /// שם תצוגה בטוח: בלי תווי בקרה/כיווניות, בלי רווחים מיותרים, ועד
  /// [maxDisplayName] תווים.
  static String sanitizeDisplayName(String? raw) {
    final cleaned = (raw ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(_unsafeChars, '')
        .trim();
    if (cleaned.length <= maxDisplayName) return cleaned;
    return cleaned.substring(0, maxDisplayName).trim();
  }

  /// קוד חדר תקין: בדיוק 5 ספרות.
  static bool isValidRoomCode(String? code) => code != null && _roomCode.hasMatch(code);

  /// זורק [StateError] ידידותי אם הקוד לא תקין - לשימוש לפני כל גישה
  /// ל-rooms/{code}, כדי שקלט כמו "12345/players/x" לא יגיע לנתיב.
  static String requireRoomCode(String code) {
    final trimmed = code.trim();
    if (!isValidRoomCode(trimmed)) {
      throw StateError('קוד החדר לא תקין.');
    }
    return trimmed;
  }

  /// תמונת פרופיל מוצגת רק מהשרתים של ספקי ההתחברות (כמו בחוקי Firestore),
  /// כדי ששחקן/ית אחר/ת לא יוכל/תוכל לגרום לטעינת כתובת שרירותית.
  static bool isTrustedPhotoUrl(String? url) {
    if (url == null || url.isEmpty || url.length > 2048) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    const hosts = ['googleusercontent.com', 'ggpht.com', 'fbcdn.net', 'facebook.com', 'fbsbx.com'];
    final host = uri.host.toLowerCase();
    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }
}
