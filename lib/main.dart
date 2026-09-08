import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (AppConfig.useFirebaseBackend) {
    try {
      await bootstrapFirebase();
    } catch (e) {
      // Firebase לא הוגדר כראוי עדיין - ממשיכים במצב מקומי בלבד כדי שהמשחק
      // לעולם לא יקרוס עבור שחקן קצה עקב תצורת backend חסרה.
      debugPrint('Firebase bootstrap skipped: $e');
    }
  }

  runApp(const ProviderScope(child: WordboxApp()));
}
