import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/room_models.dart';

/// מסך "יצירת חדר" למשחק מול חברים אמיתי: מנהל/ת החדר קובע/ת כאן את כל
/// הגדרות המשחק (גודל לוח, משך הסבב, ניקוד יעד, מספר משחקונים, דמי כניסה,
/// זמן פתיחת ההצטרפות), ואז מקבל/ת קוד חדר לשיתוף.
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
  int _totalRounds = 1;
  int _entryFee = 5;
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

  int get _myCoins => ref.read(playerProfileProvider).valueOrNull?.coins ?? 0;
  bool get _canAfford => _myCoins >= _entryFee;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'אנא הזינו שם/כינוי.');
      return;
    }
    if (!_canAfford) {
      setState(() => _error = 'אין מספיק מטבעות (צריך $_entryFee, יש $_myCoins).');
      return;
    }
    setState(() {
      _isCreating = true;
      _error = null;
    });

    final spent = await ref.read(playerProfileProvider.notifier).spendCoins(_entryFee);
    if (!spent) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'אין מספיק מטבעות (צריך $_entryFee).';
      });
      return;
    }

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final room = await repo.createRoom(
        hostDisplayName: name,
        gridSize: _gridSize,
        roundSeconds: _roundSeconds,
        targetScore: _targetScore,
        maxPlayers: GameRoom.defaultMaxPlayers,
        joinWindow: Duration(minutes: _joinWindowMinutes),
        totalRounds: _totalRounds,
        entryFee: _entryFee,
      );
      if (!mounted) return;
      context.pushReplacement('/multiplayer/online/room/${room.roomCode}');
    } catch (e) {
      await ref.read(playerProfileProvider.notifier).addCoins(_entryFee);
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'לא הצלחנו ליצור חדר: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(playerProfileProvider).valueOrNull?.coins ?? 0;

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
          _SettingSlider(
            title: 'כמה זמן לכל תור (סבב)?',
            valueLabel: '$_roundSeconds שנ׳',
            value: _roundSeconds.toDouble(),
            min: 30,
            max: 180,
            divisions: 15,
            onChanged: (v) => setState(() => _roundSeconds = v.round()),
          ),
          const SizedBox(height: 16),
          _SettingSlider(
            title: 'עד כמה נקודות המשחק? (ניקוד יעד לניצחון מוקדם)',
            valueLabel: _targetScore == 0 ? 'ללא יעד' : '$_targetScore נק׳',
            value: _targetScore.toDouble(),
            min: 0,
            max: 1000,
            divisions: 40,
            onChanged: (v) => setState(() => _targetScore = (v / 25).round() * 25),
          ),
          const SizedBox(height: 16),
          _SettingSlider(
            title: 'כמה משחקונים בסדרה?',
            valueLabel: _totalRounds == 1 ? 'משחקון אחד' : '$_totalRounds משחקונים',
            value: _totalRounds.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => setState(() => _totalRounds = v.round()),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'דמי כניסה (נגבים מכל מי שנכנס, כולל אותך)',
            child: Column(
              children: [
                _ChipRow<int>(
                  values: GameRoom.allowedEntryFees,
                  selected: _entryFee,
                  labelBuilder: (v) => '$v מטבעות',
                  onSelected: (v) => setState(() => _entryFee = v),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: AppColors.star, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      'יתרה: $coins',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: coins >= _entryFee ? AppColors.textDark : AppColors.error,
                      ),
                    ),
                  ],
                ),
                if (coins < _entryFee) ...[
                  const SizedBox(height: 8),
                  Text(
                    'אין מספיק מטבעות (צריך $_entryFee)',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
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
            onPressed: (_isCreating || coins < _entryFee) ? null : _create,
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

class _SettingSlider extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
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
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: AppColors.primaryDark,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
              thumbColor: AppColors.primaryDark,
              overlayColor: AppColors.primary.withValues(alpha: 0.16),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
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
