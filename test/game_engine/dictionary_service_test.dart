import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the real bundled Hebrew dictionary asset', () async {
    final service = DictionaryService.instance;
    await service.load();

    expect(service.isLoaded, isTrue);
    expect(service.allWords.length, greaterThan(500));
    // "בית" מנורמל נשאר "בית" (אין אותיות סופיות במילה הזו).
    expect(service.isValidNormalizedWord('בית'), isTrue);
  });
}
