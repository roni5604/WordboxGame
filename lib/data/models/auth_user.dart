import 'package:equatable/equatable.dart';

/// ספק ההתחברות ששימש ליצירת המשתמש - נשמר כדי שנוכל להציג בפרופיל
/// "מחובר/ת עם Google" וכו', ולדעת אילו כפתורים להציג/להסתיר.
enum AuthProviderType { guest, google, apple, facebook, email }

/// ייצוג פשוט ואחיד של "מי מחובר עכשיו", בלי תלות ישירה ב-Firebase בשאר
/// האפליקציה (כדי שאפשר יהיה להחליף מימוש בלי לגעת במסכים).
class AuthUser extends Equatable {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isAnonymous;
  final AuthProviderType provider;

  const AuthUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.isAnonymous,
    required this.provider,
  });

  @override
  List<Object?> get props => [uid, displayName, email, photoUrl, isAnonymous, provider];
}

/// שגיאת התחברות ידידותית בעברית - ה-UI מציג את [message] ישירות למשתמש/ת.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
