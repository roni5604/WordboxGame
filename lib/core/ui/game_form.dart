import 'package:flutter/material.dart';

import 'candy_button.dart';
import 'pressable.dart';

/// רכיבי טופס משותפים למסכי הגדרות משחק (יצירת חדר, תחרות מול המחשב):
/// כרטיס סעיף לבן, שורת שבבי-בחירה בסגנון candy, ומחוון עם ערך גדול.

class GameSlider extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const GameSlider({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GameSectionCard(
      title: title,
      child: Column(
        children: [
          Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF5B2EC9)),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF7B3FF2),
              inactiveTrackColor: const Color(0xFF7B3FF2).withValues(alpha: 0.18),
              thumbColor: const Color(0xFF5B2EC9),
              overlayColor: const Color(0xFF7B3FF2).withValues(alpha: 0.16),
              trackHeight: 6,
            ),
            child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class GameSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const GameSectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF4A2F8F)),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class GameChipRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  /// צבע הבחירה (ברירת מחדל סגול, כמו במסכי החברים).
  final CandyPalette palette;

  const GameChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.palette = CandyPalette.purple,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: values.map((v) {
        final isSelected = v == selected;
        return Pressable(
          onTap: () => onSelected(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(colors: [palette.top, palette.bottom]) : null,
              color: isSelected ? null : palette.top.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected ? [BoxShadow(color: palette.lip, offset: const Offset(0, 3))] : null,
            ),
            child: Text(
              labelBuilder(v),
              style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? Colors.white : const Color(0xFF4A2F8F)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
