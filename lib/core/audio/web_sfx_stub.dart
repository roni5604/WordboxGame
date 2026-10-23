/// מחוץ לדפדפן אין Web Audio - SoundService משתמש ב-audioplayers.
class WebSfx {
  static WebSfx? create() => null;

  void preload(Iterable<String> files) {}

  void play(String file, double volume, {String? channel}) {}

  void dispose() {}
}
