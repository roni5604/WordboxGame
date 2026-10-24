import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/widgets/avatar_widget.dart';

/// המילים של משתתף/ת אחד/ת בתחרות.
class RaceWordList {
  final String name;
  final String avatarId;
  final List<String> words; // בצורת תצוגה, לפי סדר המציאה
  final bool isMe;

  const RaceWordList({required this.name, required this.avatarId, required this.words, this.isMe = false});
}

/// מחיר "הצצה" למילים של היריבים לתחרות אחת.
const int kSpyCost = 50;

/// לוח המילים בתחתית התחרות: לשונית "שלי" ולשונית לכל יריב. המילים של
/// היריבים נעולות עד שקונים "הצצה" ב-[kSpyCost] מטבעות - אז הלשוניות נפתחות
/// ומילים חדשות שהם מוצאים "נוחתות" עם אנימציה בזמן אמת.
class RaceWordsPanel extends StatefulWidget {
  final RaceWordList mine;
  final List<RaceWordList> opponents;
  final bool unlocked;
  final VoidCallback onUnlock;

  /// במשחק חי (בלי השהיה) - במקום דיאלוג: נגיעה ראשונה בלשונית נעולה
  /// הופכת אותה ל"לאשר?" לכמה שניות, ונגיעה שנייה קונה.
  final bool confirmInline;

  const RaceWordsPanel({
    super.key,
    required this.mine,
    required this.opponents,
    required this.unlocked,
    required this.onUnlock,
    this.confirmInline = false,
  });

  @override
  State<RaceWordsPanel> createState() => _RaceWordsPanelState();
}

class _RaceWordsPanelState extends State<RaceWordsPanel> {
  int _tab = 0; // 0 = שלי
  int? _confirming;
  Timer? _confirmTimer;

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(RaceWordsPanel old) {
    super.didUpdateWidget(old);
    // מיד אחרי הקנייה - קופצים ליריב הראשון כדי לראות מה קנינו.
    if (!old.unlocked && widget.unlocked && widget.opponents.isNotEmpty) _tab = 1;
    if (_tab > widget.opponents.length) _tab = 0;
  }

  void _select(int i) {
    Haptics.selection();
    if (i > 0 && !widget.unlocked) {
      if (widget.confirmInline && _confirming != i) {
        _confirmTimer?.cancel();
        setState(() => _confirming = i);
        _confirmTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _confirming = null);
        });
        return;
      }
      _confirmTimer?.cancel();
      setState(() => _confirming = null);
      widget.onUnlock();
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final lists = [widget.mine, ...widget.opponents];
    final current = lists[_tab.clamp(0, lists.length - 1)];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _Tab(
                list: lists[i],
                selected: i == _tab,
                locked: i > 0 && !widget.unlocked,
                confirming: i == _confirming,
                onTap: () => _select(i),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: current.words.isEmpty
                    ? Center(
                        child: Text(
                          current.isMe
                              ? 'המילה הראשונה מחכה לכם - גררו אותיות סמוכות!'
                              : '${current.name} עוד לא מצא/ה מילים',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        itemCount: current.words.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final word = current.words[current.words.length - 1 - index];
                          return _WordChip(
                            key: ValueKey('${current.name}-$word'),
                            word: word,
                            isMe: current.isMe,
                            fresh: index == 0,
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final RaceWordList list;
  final bool selected;
  final bool locked;
  final bool confirming;
  final VoidCallback onTap;

  const _Tab({
    required this.list,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.confirming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? 'הצצה למילים של ${list.name} - $kSpyCost מטבעות' : 'המילים של ${list.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: selected ? Colors.white : Colors.white.withValues(alpha: locked ? 0.12 : 0.22),
            border: Border.all(color: Colors.white.withValues(alpha: selected ? 1 : 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWidget(avatarId: list.avatarId, size: 26, ring: false),
              const SizedBox(width: 5),
              Text(
                list.isMe ? 'שלי' : list.name,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: selected ? const Color(0xFF4B2BB5) : Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              if (locked && confirming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF1FB86A), borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'לאשר? $kSpyCost',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.08, duration: 420.ms)
              else if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFF9F1C)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, size: 12, color: Color(0xFF6B3A00)),
                      SizedBox(width: 2),
                      Text(
                        '$kSpyCost',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF6B3A00)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF7B3FF2) : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${list.words.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final bool isMe;
  final bool fresh;

  const _WordChip({super.key, required this.word, required this.isMe, required this.fresh});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: isMe ? null : Border.all(color: const Color(0xFFFFB259), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: Text(
        word,
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 15),
      ),
    );
    if (!fresh) return chip;
    return chip
        .animate()
        .fadeIn(duration: 220.ms)
        .slideY(begin: -0.9, curve: Curves.easeOutBack, duration: 420.ms)
        .then()
        .shimmer(duration: 700.ms, color: const Color(0xFFFFE27A));
  }
}
