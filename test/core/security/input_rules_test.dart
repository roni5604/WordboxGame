import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/security/input_rules.dart';

void main() {
  group('InputRules', () {
    test('room codes: exactly 5 digits', () {
      expect(InputRules.isValidRoomCode('12345'), isTrue);
      expect(InputRules.isValidRoomCode('1234'), isFalse);
      expect(InputRules.isValidRoomCode('12345/players/x'), isFalse);
      expect(InputRules.isValidRoomCode('abcde'), isFalse);
      expect(InputRules.isValidRoomCode(null), isFalse);
      expect(() => InputRules.requireRoomCode('../x'), throwsStateError);
      expect(InputRules.requireRoomCode(' 54321 '), '54321');
    });

    test('display names: strip control and bidi characters, cap length', () {
      expect(InputRules.sanitizeDisplayName('  דנה  '), 'דנה');
      expect(InputRules.sanitizeDisplayName('ab\u202Ecd'), 'abcd');
      expect(InputRules.sanitizeDisplayName('a\nb\tc'), 'a b c');
      expect(InputRules.sanitizeDisplayName('x' * 40).length, InputRules.maxDisplayName);
      expect(InputRules.sanitizeDisplayName(null), '');
    });

    test('offensive names are detected, including obfuscation', () {
      for (final bad in ['זונה', 'בן זונה', 'ש.ר.מ.ו.ט.ה', 'כוס אמק', 'מניאק123', 'f u c k', 'Fuuck'.replaceAll('uu', 'u'), 'sh1t', 'B!tch', 'נאצי', 'זין', 'ass']) {
        expect(InputRules.isOffensiveName(bad), isTrue, reason: bad);
        expect(InputRules.sanitizeDisplayName(bad), '', reason: bad);
      }
    });

    test('ordinary names are not flagged', () {
      for (final ok in ['דנה', 'רוני', 'כוסמת', 'זינגר', 'תחתית', 'Cassie', 'Dickens', 'Sussex', 'Grape', 'מוצץ', 'Roni M', 'שחקן/ית', 'מלך המילים', 'גלעד']) {
        expect(InputRules.isOffensiveName(ok), isFalse, reason: ok);
        expect(InputRules.sanitizeDisplayName(ok), isNotEmpty, reason: ok);
      }
    });

    test('photo URLs: only https from login providers', () {
      expect(InputRules.isTrustedPhotoUrl('https://lh3.googleusercontent.com/a/x=s96'), isTrue);
      expect(InputRules.isTrustedPhotoUrl('http://lh3.googleusercontent.com/a/x'), isFalse);
      expect(InputRules.isTrustedPhotoUrl('https://evil.example/x.png'), isFalse);
      expect(InputRules.isTrustedPhotoUrl('https://googleusercontent.com.evil.example/x'), isFalse);
      expect(InputRules.isTrustedPhotoUrl(null), isFalse);
    });
  });
}
