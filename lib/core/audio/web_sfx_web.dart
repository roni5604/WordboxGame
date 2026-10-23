import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// אפקטים קוליים בדפדפן דרך Web Audio API.
///
/// audioplayers מנגן באתר דרך אלמנטי &lt;audio&gt;: כל צליל טוען מחדש את
/// הקובץ לאחד מכמה נגנים מתחלפים, וזה יוצר דיליי וקטיעות - בעיקר כשגוררים
/// אצבע על אותיות ומנגנים צליל לכל אות. כאן כל קובץ מפוענח פעם אחת לזיכרון
/// (AudioBuffer) ומתנגן מיד, בלי הגבלה על צלילים חופפים, דרך מדחס עדין
/// שמונע "צריבה" כשכמה צלילים מתנגנים יחד.
class WebSfx {
  WebSfx._(this._ctx, this._out);

  final web.AudioContext _ctx;
  final web.AudioNode _out;
  final _buffers = <String, web.AudioBuffer>{};
  final _loading = <String, Future<web.AudioBuffer?>>{};

  /// הצליל האחרון בכל "ערוץ" (למשל אותיות) - דועך כשמגיע הבא, כדי שרצף
  /// מהיר יישמע נקי ולא כגוש צלילים חופפים.
  final _channels = <String, web.GainNode>{};

  static WebSfx? create() {
    try {
      final ctx = web.AudioContext();
      final compressor = ctx.createDynamicsCompressor()
        ..threshold.value = -16
        ..knee.value = 14
        ..ratio.value = 3
        ..attack.value = 0.003
        ..release.value = 0.18;
      final master = ctx.createGain()..gain.value = 0.95;
      master.connect(compressor);
      compressor.connect(ctx.destination);
      return WebSfx._(ctx, master);
    } catch (_) {
      return null;
    }
  }

  Future<web.AudioBuffer?> _load(String file) => _loading[file] ??= () async {
        try {
          final url = ui_web.assetManager.getAssetUrl('assets/audio/$file');
          final response = await web.window.fetch(url.toJS).toDart;
          final data = await response.arrayBuffer().toDart;
          final buffer = await _ctx.decodeAudioData(data).toDart;
          _buffers[file] = buffer;
          return buffer;
        } catch (_) {
          return null;
        }
      }();

  /// טעינה ופענוח מראש - לפי הסדר, כדי שצלילי המשחק יהיו מוכנים ראשונים.
  void preload(Iterable<String> files) {
    unawaited(() async {
      for (final file in files) {
        await _load(file);
      }
    }());
  }

  void play(String file, double volume, {String? channel}) {
    // הדפדפן משעה את ההקשר עד מגע ראשון; הצליל מופעל בתוך אירוע המגע.
    if (_ctx.state == 'suspended') _ctx.resume();
    final buffer = _buffers[file];
    if (buffer != null) {
      _start(buffer, volume, channel);
      return;
    }
    // קובץ שעוד לא נטען: מנגנים רק אם הוא מוכן מהר - צליל באיחור גרוע מבלי צליל.
    final requested = _ctx.currentTime;
    _load(file).then((b) {
      if (b != null && _ctx.currentTime - requested < 0.25) _start(b, volume, channel);
    });
  }

  void _start(web.AudioBuffer buffer, double volume, String? channel) {
    final now = _ctx.currentTime;
    if (channel != null) {
      final previous = _channels[channel];
      if (previous != null) {
        previous.gain
          ..cancelScheduledValues(now)
          ..setValueAtTime(previous.gain.value, now)
          ..linearRampToValueAtTime(0, now + 0.07);
      }
    }
    final gain = _ctx.createGain();
    // התחלה רכה של 4ms - בלי "קליק" בתחילת הצליל.
    gain.gain
      ..setValueAtTime(0, now)
      ..linearRampToValueAtTime(volume, now + 0.004);
    final source = _ctx.createBufferSource()..buffer = buffer;
    source.connect(gain);
    gain.connect(_out);
    source.start(now);
    if (channel != null) _channels[channel] = gain;
  }

  void dispose() {
    _ctx.close();
  }
}
