import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/game_form.dart';
import '../../core/ui/pressable.dart';
import '../../game_engine/bot_player.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/race_config.dart';

const _botNamePool = ['עומר', 'נועה', 'דנה', 'יובל', 'טל', 'מאיה', 'איתי', 'שירה'];

/// מסך "יצירת חדר" לתחרות מקומית: בוחרים כמה משתתפים (2-4), רמת קושי
/// ליריבים, גודל לוח וזמן משחק. כרגע זו תחרות מקומית מול "בוטים"
/// (סימולציית שחקנים) - ברגע שיחובר שרת רב-משתתפים אמיתי (ראו
/// docs/FIREBASE_SETUP.md) ניתן יהיה להחליף בוטים בשחקנים אמיתיים
/// בלי לשנות את מסך המשחק/תוצאות.
class RaceSetupScreen extends ConsumerStatefulWidget {
  const RaceSetupScreen({super.key});

  @override
  ConsumerState<RaceSetupScreen> createState() => _RaceSetupScreenState();
}

class _RaceSetupScreenState extends ConsumerState<RaceSetupScreen> {
  int _totalPlayers = 2;
  BotDifficulty _difficulty = BotDifficulty.normal;
  int _gridSize = 4;
  int _timeSeconds = 90;
  late final _nameController = TextEditingController(text: _defaultName());

  String _defaultName() {
    final name = ref.read(playerProfileProvider).valueOrNull?.displayName.trim() ?? '';
    return name.isEmpty || name == 'שחקן/ית' ? 'את/ה' : name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _start() {
    final botCount = _totalPlayers - 1;
    final bots = List.generate(
      botCount,
      (i) => BotSetup(name: _botNamePool[i % _botNamePool.length], difficulty: _difficulty),
    );

    final config = RaceConfig(
      gridSize: _gridSize,
      timeLimit: Duration(seconds: _timeSeconds),
      humanName: _nameController.text.trim().isEmpty ? 'את/ה' : _nameController.text.trim(),
      bots: bots,
    );

    context.push('/multiplayer/race', extra: config);
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      GameSectionCard(
        title: 'כמה משתתפים?',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final n in [2, 3, 4])
              _PlayersChoice(count: n, selected: _totalPlayers == n, onTap: () => setState(() => _totalPlayers = n)),
          ],
        ),
      ),
      GameSectionCard(
        title: 'השם שלך בתחרות',
        child: TextField(
          controller: _nameController,
          textAlign: TextAlign.center,
          maxLength: 16,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFEFF6FF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ),
      GameSectionCard(
        title: 'רמת היריבים',
        child: GameChipRow<BotDifficulty>(
          values: BotDifficulty.values,
          selected: _difficulty,
          labelBuilder: (d) => d.labelHe,
          palette: CandyPalette.blue,
          onSelected: (d) => setState(() => _difficulty = d),
        ),
      ),
      GameSectionCard(
        title: 'גודל לוח',
        child: GameChipRow<int>(
          values: const [4, 5, 6],
          selected: _gridSize,
          labelBuilder: (v) => '$v×$v',
          palette: CandyPalette.blue,
          onSelected: (v) => setState(() => _gridSize = v),
        ),
      ),
      GameSectionCard(
        title: 'משך התחרות',
        child: GameChipRow<int>(
          values: const [60, 90, 120],
          selected: _timeSeconds,
          labelBuilder: (v) => '$v שנ׳',
          palette: CandyPalette.blue,
          onSelected: (v) => setState(() => _timeSeconds = v),
        ),
      ),
    ];

    return GameScaffold(
      colors: kVsComputerGradient,
      header: GameHeader(
        title: 'שחק נגד המחשב',
        subtitle: 'מי מוצא/ת הכי הרבה מילים?',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      bottomBar: CandyButton(
        label: 'בואו נתחרה!',
        icon: Icons.flag_rounded,
        palette: CandyPalette.green,
        height: 62,
        fontSize: 22,
        onPressed: _start,
      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        children: [
          const Center(child: MascotWidget(mood: MascotMood.excited, size: 84)),
          const SizedBox(height: 12),
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cards[i]
                .animate()
                .fadeIn(delay: (60 * i).ms, duration: 260.ms)
                .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
          ],
        ],
      ),
    );
  }
}

/// צבעי "שחק נגד המחשב" - תואמים לכפתור הכחול במסך הבית.
const kVsComputerGradient = [Color(0xFF38BDF8), Color(0xFF3B82F6), Color(0xFF6366F1)];

/// בחירת מספר משתתפים: עיגול עם מספר וקמעות קטנים שמראים כמה יריבים יהיו.
class _PlayersChoice extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayersChoice({required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: '$count משתתפים',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        width: selected ? 84 : 74,
        height: selected ? 84 : 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6FD3FF), Color(0xFF2E8BFF)],
                )
              : null,
          color: selected ? null : const Color(0xFFEFF6FF),
          border: Border.all(color: selected ? Colors.white : const Color(0xFFD6E6FF), width: 3),
          boxShadow: selected ? const [BoxShadow(color: Color(0xFF1A5BC4), offset: Offset(0, 4))] : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1E3A8A),
                fontWeight: FontWeight.w900,
                fontSize: 26,
                height: 1,
              ),
            ),
            Text(
              count == 2 ? '1 יריב' : '${count - 1} יריבים',
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF3B5BA9),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
