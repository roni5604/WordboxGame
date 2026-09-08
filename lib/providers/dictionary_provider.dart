import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_engine/dictionary/dictionary_service.dart';

/// טוען את מילון המשחק פעם אחת בתחילת חיי האפליקציה.
final dictionaryLoadProvider = FutureProvider<DictionaryService>((ref) async {
  await DictionaryService.instance.load();
  return DictionaryService.instance;
});
