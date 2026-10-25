import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../avatars/avatar_catalog.dart';
import 'avatar_widget.dart';

/// בורר הדמויות בעריכת הפרופיל: תצוגה גדולה של הנבחרת, לשוניות קטגוריה
/// (קלאסי / ילדים / דמויות / כלבים / חיות), ורשת דמויות עם קפיצה בבחירה.
class AvatarPicker extends StatefulWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const AvatarPicker({super.key, required this.selectedId, required this.onSelected});

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  late AvatarCategory _category = _categoryOf(widget.selectedId);

  static AvatarCategory _categoryOf(String id) => paintedAvatarFor(id)?.category ?? AvatarCategory.classic;

  List<(String id, String label)> _items(AvatarCategory c) {
    if (c == AvatarCategory.classic) return [for (final o in kAvatarOptions) (o.id, o.label)];
    return [
      for (final a in kPaintedAvatars)
        if (a.category == c) (a.id, a.label),
    ];
  }

  String _labelOf(String id) =>
      paintedAvatarFor(id)?.label ?? kAvatarOptions.where((o) => o.id == id).map((o) => o.label).firstOrNull ?? '';

  @override
  Widget build(BuildContext context) {
    final items = _items(_category);
    final screenH = MediaQuery.sizeOf(context).height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (c, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                child: c,
              ),
              child: Container(
                key: ValueKey(widget.selectedId),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 18)],
                ),
                child: AvatarWidget(avatarId: widget.selectedId, size: 84),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'הדמות שלך',
                    style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _labelOf(widget.selectedId),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  ),
                  Text(
                    '${kPaintedAvatars.length + kAvatarOptions.length} דמויות לבחירה',
                    style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AvatarCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final c = AvatarCategory.values[i];
              final selected = c == _category;
              return GestureDetector(
                onTap: () {
                  Haptics.selection();
                  setState(() => _category = c);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    gradient: selected ? const LinearGradient(colors: [Color(0xFFFFB259), Color(0xFFFF7A45)]) : null,
                    color: selected ? null : const Color(0xFFF2EEF8),
                    boxShadow: selected
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 17, color: selected ? Colors.white : const Color(0xFF7A7090)),
                      const SizedBox(width: 5),
                      Text(
                        c.labelHe,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : const Color(0xFF5E5578),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          // הרשת נגללת בתוך גובה קבוע, כך שהגיליון לא גולש מהמסך.
          height: (screenH * 0.3).clamp(170.0, 300.0),
          child: GridView.builder(
            key: ValueKey(_category),
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 76,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final (id, label) = items[i];
              final selected = id == widget.selectedId;
              return Semantics(
                button: true,
                selected: selected,
                label: label,
                child:
                    GestureDetector(
                          onTap: () {
                            Haptics.light();
                            widget.onSelected(id);
                          },
                          child: LayoutBuilder(
                            builder: (context, cell) {
                              // הדמות תופסת את מה שנשאר אחרי שורת השם - בלי גלישה בשום גודל טקסט.
                              final avatar = (cell.maxHeight - 26).clamp(28.0, cell.maxWidth - 8);
                              return Column(
                                children: [
                                  AnimatedScale(
                                    scale: selected ? 1.08 : 1,
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutBack,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selected ? AppColors.primary : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: AvatarWidget(avatarId: id, size: avatar - 12, ring: false),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                                          color: selected ? AppColors.primaryDark : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                        .animate()
                        .fadeIn(delay: (i * 18).ms, duration: 200.ms)
                        .scaleXY(begin: 0.85, curve: Curves.easeOutBack),
              );
            },
          ),
        ),
      ],
    );
  }
}
