import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/audio/music_service.dart';

void main() {
  test('music plays only when enabled, in the foreground and with no ad on screen', () {
    final music = MusicService.silent();
    expect(music.shouldPlay, isTrue);

    music.enabled = false;
    expect(music.shouldPlay, isFalse);
    music.enabled = true;

    music.foreground = false;
    expect(music.shouldPlay, isFalse);
    music.foreground = true;

    music.adShowing = true;
    expect(music.shouldPlay, isFalse);
    music.adShowing = false;

    expect(music.shouldPlay, isTrue);
  });

  test('userInteracted keeps music allowed', () {
    final music = MusicService.silent()..userInteracted();
    expect(music.shouldPlay, isTrue);
  });

  test('music stops while a game screen is open and returns after leaving', () {
    final music = MusicService.silent();
    music.enterGame();
    expect(music.shouldPlay, isFalse);
    // מעבר לשלב הבא: המסך החדש נפתח לפני שהקודם נסגר
    music.enterGame();
    music.leaveGame();
    expect(music.shouldPlay, isFalse);
    music.leaveGame();
    expect(music.shouldPlay, isTrue);
    music.leaveGame(); // לא יורד מתחת לאפס
    expect(music.shouldPlay, isTrue);
  });
}
