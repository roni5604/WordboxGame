import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';

/// מסך "יצירת חדר" למשחק מול חברים אמיתי: מנהל/ת החדר קובע/ת כאן את כל
/// הגדרות המשחק (גודל לוח, משך הסבב, ניקוד יעד, מספר שחקנים, זמן פתיחת
/// ההצטרפות), ואז מקבל/ת קוד חדר לשיתוף. ראו lib/features/multiplayer/room_lobby_screen.dart
/// להמשך הזרימה (חדר המתנה עד שהמנהל/ת לוחץ/ת "התחל משחק").
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  late final TextEditingController _nameController;
  int _gridSize = 5;
  int _roundSeconds = 90;
  int _targetScore = 0;
  int _maxPlayers = 6;
  int _joinWindowMinutes = 10;
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider).valueOrNull;
    final defaultName = profile != null && profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'את/ה';
    _nameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'אנא הזינו שם/כינוי.');
      return;
    }
    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final room = await repo.createRoom(
        hostDisplayName: name,
        gridSize: _gridSize,
        roundSeconds: _roundSeconds,
        targetScore: _targetScore,
        maxPlayers: _maxPlayers,
        joinWindow: Duration(minutes: _joinWindowMinutes),
      );
      if (!mounted) return;
      context.pushReplacement('/multiplayer/online/room/${room.roomCode}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'לא הצלחנו ליצור חדר: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('יצירת חדר - משחק מול חברים'),
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
              'תקבלו קוד לשיתוף - חברים יכולים להצטרף איתו לחדר שלכם',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'שם/כינוי שלך',
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              maxLength: 16,
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.background.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'גודל לוח',
            child: _ChipRow<int>(
              values: const [4, 5, 6, 7],
              selected: _gridSize,
              labelBuilder: (v) => '$v×$v',
              onSelected: (v) => setState(() => _gridSize = v),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'כמה זמן לכל תור (סבב)?',
            child: _ChipRow<int>(
              values: const [60, 90, 120, 180],
              selected: _roundSeconds,
              labelBuilder: (v) => '$v שנ׳',
              onSelected: (v) => setState(() => _roundSeconds = v),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'עד כמה נקודות המשחק? (ניקוד יעד לניצחון מוקדם)',
            child: _ChipRow<int>(
              values: const [0, 150, 300, 500],
              selected: _targetScore,
              labelBuilder: (v) => v == 0 ? 'ללא יעד' : '$v נק׳',
              onSelected: (v) => setState(() => _targetScore = v),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'כמה שחקנים מקסימום?',
            child: _ChipRow<int>(
              values: const [2, 4, 6, 8],
              selected: _maxPlayers,
              labelBuilder: (v) => '$v',
              onSelected: (v) => setState(() => _maxPlayers = v),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'כמה זמן ניתן להצטרף עם הקוד?',
            child: _ChipRow<int>(
              values: const [5, 10, 20],
              selected: _joinWindowMinutes,
              labelBuilder: (v) => '$v דק׳',
              onSelected: (v) => setState(() => _joinWindowMinutes = v),
            ),
          ),
          const SizedBox(height: 32),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ElevatedButton(
            onPressed: _isCreating ? null : _create,
            child: _isCreating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('יצירת חדר 🔑'),
          ).animate().fadeIn(delay: 200.ms),
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

class _ChipRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const _ChipRow({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: values.map((v) {
        final isSelected = v == selected;
        return ChoiceChip(
          label: Text(labelBuilder(v)),
          selected: isSelected,
          onSelected: (_) => onSelected(v),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark),
        );
      }).toList(),
    );
  }
}
