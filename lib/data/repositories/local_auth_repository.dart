import 'dart:async';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/auth_user.dart';
import 'auth_repository.dart';

/// מימוש "אורח בלבד" - פעיל כברירת מחדל (כש-AppConfig.useFirebaseBackend
/// כבוי), ומייצג את המשחק כפי שהוא היום: אין שרת, אין חשבון אמיתי, אבל
/// עדיין יש "מזהה אורח" יציב שנשמר מקומית כדי שממשק המשתמש (פרופיל)
/// יוכל תמיד להציג משתמש מחובר.
///
/// כל ניסיון להתחבר עם חשבון אמיתי (Google/Apple/Facebook/מייל) זורק
/// [AuthException] עם הסבר ידידותי שיש להפעיל קודם Firebase - כך שהכפתורים
/// כבר עובדים ומוכנים בממשק, אך לא "מתחזים" להתחברות אמיתית שלא קיימת.
class LocalAuthRepository implements AuthRepository {
  static const _boxName = 'wordbox_auth';

  Box? _box;
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  Future<Box> _openBox() async => _box ??= await Hive.openBox(_boxName);

  Future<String> _guestId() async {
    final box = await _openBox();
    var id = box.get('guest_id') as String?;
    if (id == null) {
      id = 'guest_${Random().nextInt(1 << 32)}_${DateTime.now().microsecondsSinceEpoch}';
      await box.put('guest_id', id);
    }
    return id;
  }

  static const _notConfigured = AuthException(
    'התחברות עם חשבון אמיתי דורשת חיבור לענן (Firebase) שעדיין לא הופעל '
    'במשחק הזה - כרגע ההתקדמות נשמרת אצלכם במכשיר כאורח/ת. '
    '(למפתחים: ראו docs/FIREBASE_SETUP.md)',
  );

  @override
  Stream<AuthUser?> authStateChanges() {
    // מבטיחים שגם מאזין שמצטרף מאוחר יקבל מיד את המצב הנוכחי.
    Future.microtask(() async {
      _current ??= await signInAsGuest();
    });
    return _controller.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInAsGuest() async {
    final id = await _guestId();
    final user = AuthUser(
      uid: id,
      isAnonymous: true,
      provider: AuthProviderType.guest,
    );
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() => throw _notConfigured;

  @override
  Future<AuthUser> signInWithApple() => throw _notConfigured;

  @override
  Future<AuthUser> signInWithFacebook() => throw _notConfigured;

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) =>
      throw _notConfigured;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      throw _notConfigured;

  @override
  Future<void> signOut() async {
    // "יציאה" עבור אורח היא לא רלוונטית באמת - פשוט נשארים אורחים.
  }
}
