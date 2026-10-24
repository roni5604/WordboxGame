import 'package:flutter/material.dart';

/// בוררי הגדרות משותפים למסכי "נגד המחשב" ו"יצירת חדר": כרטיס לבן
/// ושורות עם "גלולה" מחליקה שזזה לבחירה (במקום צ'יפים).

class SettingsPanel extends StatelessWidget {
  final List<Widget> children;

  const SettingsPanel({super.key, required this.children, this.gap = 8});

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEFF5FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
        ],
      ),
    );
  }
}

/// שורת הגדרה: אייקון + שם, ובורר מחליק עם "גלולה" שזזה לבחירה.
class SegmentedSetting<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  /// גובה הבורר (נמוך יותר במסכים קטנים).
  final double height;

  const SegmentedSetting({
    super.key,
    this.height = 42,
    required this.icon,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = values.length == 1 ? 0.0 : -1 + index * 2 / (values.length - 1);
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 5),
              // גדלי טקסט גדולים (נגישות) מקטינים את התווית במקום לגלוש.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFFE3EDFF), borderRadius: BorderRadius.circular(14)),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  alignment: Alignment(rtl ? -x : x, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / values.length,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6FD3FF), Color(0xFF2E8BFF)],
                        ),
                        boxShadow: const [BoxShadow(color: Color(0xFF1A5BC4), offset: Offset(0, 3))],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final v in values)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: v == selected,
                          label: '$label ${labelOf(v)}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(v),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: v == selected ? Colors.white : const Color(0xFF3B5BA9),
                                ),
                                child: FittedBox(fit: BoxFit.scaleDown, child: Text(labelOf(v), maxLines: 1)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
