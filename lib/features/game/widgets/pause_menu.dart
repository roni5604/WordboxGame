import 'package:flutter/material.dart';

import '../../../core/ui/candy_button.dart';
import '../../../core/ui/game_dialog.dart';
import 'mascot_widget.dart';

enum PauseChoice { resume, restart, exit }

/// תפריט השהיה בסגנון משחקי מובייל: הלוח מוסתר מאחורי טשטוש (כדי שלא
/// יהיה אפשר "לחשוב" בזמן שהשעון עצור), והכפתורים גדולים וברורים.
/// נפתח גם מכפתור ההשהיה וגם מתנועת "חזרה" של המערכת - כך החלקה אחורה
/// בטעות באמצע שלב לעולם לא מוציאה מהמשחק.
Future<PauseChoice> showPauseMenu(
  BuildContext context, {
  String title = 'המשחק מושהה',
  String? subtitle,
  bool canRestart = true,
  String exitLabel = 'יציאה למפת השלבים',
  String? exitWarning,
}) async {
  final result = await showGameDialog<PauseChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => GameDialog(
      title: title,
      ribbon: CandyPalette.blue,
      hero: Column(
        children: [
          const MascotWidget(mood: MascotMood.idle, size: 84),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4A3F6B)),
            ),
          ],
        ],
      ),
      actions: [
        CandyButton(
          label: 'המשך לשחק',
          icon: Icons.play_arrow_rounded,
          palette: CandyPalette.green,
          height: 58,
          onPressed: () => Navigator.of(dialogContext).pop(PauseChoice.resume),
        ),
        if (canRestart)
          CandyButton(
            label: 'התחלה מחדש',
            icon: Icons.replay_rounded,
            palette: CandyPalette.orange,
            height: 52,
            fontSize: 17,
            onPressed: () => Navigator.of(dialogContext).pop(PauseChoice.restart),
          ),
        CandyButton(
          label: exitLabel,
          icon: Icons.logout_rounded,
          palette: CandyPalette.white,
          height: 50,
          fontSize: 16,
          onPressed: () => Navigator.of(dialogContext).pop(PauseChoice.exit),
        ),
        if (exitWarning != null)
          Text(
            exitWarning,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A80A8)),
          ),
      ],
    ),
  );
  return result ?? PauseChoice.resume;
}

/// ספירה לאחור "3, 2, 1, יאללה!" לפני תחילת תחרות - נותנת רגע להתכונן
/// ומייצרת תחושת "זירה" כמו במשחקים תחרותיים.
class StartCountdown extends StatefulWidget {
  final VoidCallback onDone;
  final int from;

  const StartCountdown({super.key, required this.onDone, this.from = 3});

  @override
  State<StartCountdown> createState() => _StartCountdownState();
}

class _StartCountdownState extends State<StartCountdown> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 700 * (widget.from + 1)),
  )..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final total = widget.from + 1;
        final position = _c.value * total;
        final step = position.floor().clamp(0, total - 1);
        final local = position - step;
        final label = step < widget.from ? '${widget.from - step}' : 'יאללה!';
        final scale = Curves.elasticOut.transform((local * 1.6).clamp(0, 1));
        final opacity = local > 0.75 ? (1 - (local - 0.75) / 0.25) : 1.0;
        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: 0.35 * (1 - (_c.value > 0.9 ? (_c.value - 0.9) * 10 : 0))),
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(
                scale: 0.4 + scale * 0.8,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: step < widget.from ? 120 : 76,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Color(0xFF4F1FB0), offset: Offset(0, 6)),
                      Shadow(color: Colors.black38, blurRadius: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
