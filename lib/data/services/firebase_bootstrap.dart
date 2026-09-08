import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// אתחול Firebase - נקרא רק אם `AppConfig.useFirebaseBackend == true`,
/// כלומר רק לאחר שהוגדר פרויקט Firebase אמיתי (ראו docs/FIREBASE_SETUP.md).
Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
