import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/bot_player.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/race_config.dart';

const _botNamePool = ['עומר', 'נועה', 'דנה', 'יובל', 'טל', 'מאיה', 'איתי', 'שירה'];

/// מסך "יצירת חדר" לתחרות מקומית: בוחרים כמה משתתפים (2-4), רמת קושי
/// ליריבים, גודל לוח וזמן משחק. כרגע זו תחרות מקומית מול "בוטים"
/// (סימולציית שחקנים) - ברגע שיחובר שרת רב-משתתפים אמיתי (ראו
/// docs/FIREBASE_SETUP.md) ניתן יהיה להחליף בוטים בשחקנים אמיתיים
/// בלי לשנות את מסך המשחק/תוצאות.
class RaceSetupScreen extends StatefulWidget {
  const RaceSetupScreen({super.key});

  @override
  State<RaceSetupScreen> createState() => _RaceSetupScreenState();
}

class _RaceSetupScreenState extends State<RaceSetupScreen> {
  int _totalPlayers = 2;
  BotDifficulty _difficulty = BotDifficulty.normal;
  int _gridSize = 4;
  int _timeSeconds = 90;
  final _nameController = TextEditingController(text: 'את/ה');

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('יצירת חדר תחרות'),
        backgroundColor: AppColors.primaryDark,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: MascotWidget(mood: MascotMood.excited, size: 90)),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'תחרות מקומית - מי מוצא הכי הרבה מילים?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'כמה משתתפים?',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [2, 3, 4].map((n) {
                final selected = _totalPlayers == n;
                return _ChoiceCircle(
                  label: '$n',
                  selected: selected,
                  onTap: () => setState(() => _totalPlayers = n),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'שם/כינוי שלך',
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'רמת קושי ליריבים',
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: BotDifficulty.values.map((d) {
                final selected = _difficulty == d;
                return ChoiceChip(
                  label: Text(d.labelHe),
                  selected: selected,
                  onSelected: (_) => setState(() => _difficulty = d),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'גודל לוח',
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [4, 5, 6].map((size) {
                final selected = _gridSize == size;
                return ChoiceChip(
                  label: Text('$size×$size'),
                  selected: selected,
                  onSelected: (_) => setState(() => _gridSize = size),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'משך התחרות',
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [60, 90, 120].map((sec) {
                final selected = _timeSeconds == sec;
                return ChoiceChip(
                  label: Text('$sec שנ׳'),
                  selected: selected,
                  onSelected: (_) => setState(() => _timeSeconds = sec),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _start,
            child: const Text('בואו נתחרה! 🏁'),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          const Text(
            'שימו לב: כרגע זו תחרות מקומית מול יריבים מדומים על אותו מכשיר.\n'
            'משחק אונליין אמיתי מול חברים בדרך! 🚀',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceCircle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCircle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : Colors.grey.shade200,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
