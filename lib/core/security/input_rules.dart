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
  /// [maxDisplayName] תווים. כינוי פוגעני ([isOffensiveName]) הופך לריק,
  /// ובמקומו מוצג השם הכללי - כך הוא לא מגיע לשחקנים אחרים בשום מסלול.
  static String sanitizeDisplayName(String? raw) {
    final cleaned = (raw ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(_unsafeChars, '')
        .trim();
    if (isOffensiveName(cleaned)) return '';
    if (cleaned.length <= maxDisplayName) return cleaned;
    return cleaned.substring(0, maxDisplayName).trim();
  }

  // מילים שאסור שיופיעו בשום מקום בכינוי (גם כחלק ממילה).
  static const _bannedAnywhere = [
    // עברית
    'זונה', 'שרמוטה', 'שרמוטות', 'מזדיין', 'מזדיינת', 'לזיין', 'זיון', 'זיונים', 'כוסית',
    'כוסאמק', 'כוסעמק', 'כוסאומו', 'כוסאמא', 'בנזונה', 'בןזונה', 'יבןזונה', 'מניאק', 'מניאקית',
    'קוקסינל', 'נאצי', 'היטלר', 'פורנו', 'לאנוס', 'תמצוץ', 'זיינתי',
    // אנגלית (אחרי המרת ספרות לאותיות)
    'fuck', 'fuk', 'shit', 'bitch', 'cunt', 'nigger', 'nigga', 'faggot', 'whore', 'slut',
    'asshole', 'pussy', 'porn', 'nazi', 'hitler', 'retard', 'dildo', 'cock', 'penis',
    'vagina', 'motherfucker', 'bastard', 'wanker',
  ];

  // מילים קצרות שהן גם מילים תמימות כחלק ממילה אחרת (למשל "כוס" ב"כוסמת"),
  // ולכן אסורות רק כמילה שלמה.
  static const _bannedWholeWord = ['כוס', 'זין', 'חרא', 'תחת', 'אנס', 'rape', 'ass', 'dick', 'fag', 'sex', 'cum', 'tits'];

  static const _leet = {'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b', '@': 'a', r'$': 's', '!': 'i'};

  static String _normalizeForFilter(String s) {
    var out = s.toLowerCase();
    // ניקוד וטעמים
    out = out.replaceAll(RegExp('[֑-ׇ]'), '');
    // אותיות סופיות -> רגילות
    const finals = {'ך': 'כ', 'ם': 'מ', 'ן': 'נ', 'ף': 'פ', 'ץ': 'צ'};
    finals.forEach((k, v) => out = out.replaceAll(k, v));
    _leet.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /// כינוי שמכיל קללה, גזענות או תוכן מיני (עברית/אנגלית), כולל ניסיונות
  /// עקיפה עם רווחים, נקודות, ניקוד או ספרות במקום אותיות.
  static bool isOffensiveName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final normalized = _normalizeForFilter(raw);
    final compact = normalized.replaceAll(RegExp(r'[^a-zא-ת]'), '');
    String norm(String w) => _normalizeForFilter(w);
    if (_bannedAnywhere.any((w) => compact.contains(norm(w)))) return true;
    final words = normalized.split(RegExp(r'[^a-zא-ת]+')).where((w) => w.isNotEmpty);
    final whole = _bannedWholeWord.map(norm).toSet();
    return words.any(whole.contains) || whole.contains(compact);
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
