import 'package:firebase_core/firebase_core.dart';

import '../../core/config/app_config.dart';
import '../../firebase_options.dart';

/// אתחול Firebase - נקרא רק אם `AppConfig.useFirebaseBackend == true`.
///
/// מוגבל בזמן: אם ספריות Firebase לא נטענות (רשת איטית/מסוננת שחוסמת את
/// ה-CDN של Google), לא נתקעים לנצח במסך הטעינה - ממשיכים במצב מקומי.
Future<void> bootstrapFirebase({Duration timeout = const Duration(seconds: 12)}) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(timeout);
}

/// האם ה-backend של Firebase פעיל בפועל (הדגל דלוק *וגם* האתחול הצליח).
/// כל ה-repositories בוחרים לפי זה בין Firebase למימוש המקומי.
bool isFirebaseBackendReady() {
  if (!AppConfig.useFirebaseBackend) return false;
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}
