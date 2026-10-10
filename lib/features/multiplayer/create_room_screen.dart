import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/social_provider.dart';
import '../social/friends_screen.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/room_models.dart';

/// מסך "יצירת חדר" למשחק מול חברים אמיתי: מנהל/ת החדר קובע/ת כאן את כל
/// הגדרות המשחק (גודל לוח, משך הסבב, ניקוד יעד, מספר משחקונים, דמי כניסה,
/// זמן פתיחת ההצטרפות), ואז מקבל/ת קוד חדר לשיתוף.
class CreateRoomScreen extends ConsumerStatefulWidget {
  /// אם נפתח מ"הזמנה למשחק" של חבר/ה - ההזמנה נשלחת אוטומטית ברגע שהחדר נוצר.
  final String? inviteFriendUid;
  final String? inviteFriendName;

  const CreateRoomScreen({super.key, this.inviteFriendUid, this.inviteFriendName});

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
        avatarId: ref.read(playerProfileProvider).valueOrNull?.avatarId,
        photoUrl: ref.read(authStateProvider).valueOrNull?.photoUrl,
      );
      final inviteUid = widget.inviteFriendUid;
      if (inviteUid != null && inviteUid.isNotEmpty) {
        try {
          await ref.read(socialRepositoryProvider).sendInvite(
                toUid: inviteUid,
                toName: widget.inviteFriendName ?? '',
                roomCode: room.roomCode,
                gridSize: room.gridSize,
                roundSeconds: room.roundSeconds,
                entryFee: room.entryFee,
              );
          if (mounted) {
            GameToast.show(
              context,
              message: 'ההזמנה נשלחה ל${widget.inviteFriendName ?? 'חבר/ה'} ⚔️',
              icon: Icons.send_rounded,
              color: const Color(0xFF7B3FF2),
            );
          }
        } catch (_) {
          // ההזמנה היא תוספת - גם אם נכשלה, החדר נוצר וקוד/קישור זמינים בלובי.
        }
      }
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
    final inviteName = widget.inviteFriendName;
    final hasInvite = widget.inviteFriendUid != null && widget.inviteFriendUid!.isNotEmpty;

    return GameScaffold(
      colors: kFriendsGradient,
      header: GameHeader(
        title: 'יצירת חדר',
        subtitle: 'משחק מול חברים',
        onBack: () => context.canPop() ? context.pop() : context.go('/play/friends'),
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          CandyButton(
            label: hasInvite ? 'יצירת חדר ושליחת הזמנה 🔑' : 'יצירת חדר 🔑',
            palette: CandyPalette.green,
            height: 62,
            loading: _isCreating,
            onPressed: (_isCreating || coins < _entryFee) ? null : _create,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          if (hasInvite)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7CEB6E), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sports_esports_rounded, color: Color(0xFF33C24D), size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'בחרו הגדרות - ו${inviteName ?? 'החבר/ה'} יקבל/תקבל הזמנה קופצת להצטרף מיד!',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scaleXY(begin: 0.95, end: 1)
          else ...[
            const Center(child: MascotWidget(mood: MascotMood.excited, size: 80)),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'תקבלו קוד וקישור לשיתוף - חברים מצטרפים איתם לחדר שלכם',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
              ),
            ),
            const SizedBox(height: 18),
          ],
          _SectionCard(
            title: 'שם/כינוי שלך',
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              maxLength: 16,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF6F2FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'גודל לוח',
            child: _ChipRow<int>(
              values: const [4, 5, 6, 7],
              selected: _gridSize,
              labelBuilder: (v) => '$v×$v',
              onSelected: (v) => setState(() => _gridSize = v),
            ),
          ),
          const SizedBox(height: 14),
          _SettingSlider(
            title: 'כמה זמן לכל תור (סבב)?',
            valueLabel: '$_roundSeconds שנ׳',
            value: _roundSeconds.toDouble(),
            min: 30,
            max: 180,
            divisions: 15,
            onChanged: (v) => setState(() => _roundSeconds = v.round()),
          ),
          const SizedBox(height: 14),
          _SettingSlider(
            title: 'עד כמה נקודות המשחק? (ניקוד יעד לניצחון מוקדם)',
            valueLabel: _targetScore == 0 ? 'ללא יעד' : '$_targetScore נק׳',
            value: _targetScore.toDouble(),
            min: 0,
            max: 1000,
            divisions: 40,
            onChanged: (v) => setState(() => _targetScore = (v / 25).round() * 25),
          ),
          const SizedBox(height: 14),
          _SettingSlider(
            title: 'כמה משחקונים בסדרה?',
            valueLabel: _totalRounds == 1 ? 'משחקון אחד' : '$_totalRounds משחקונים',
            value: _totalRounds.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => setState(() => _totalRounds = v.round()),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _SectionCard(
            title: 'כמה זמן ניתן להצטרף עם הקוד?',
            child: _ChipRow<int>(
              values: const [5, 10, 20],
              selected: _joinWindowMinutes,
              labelBuilder: (v) => '$v דק׳',
              onSelected: (v) => setState(() => _joinWindowMinutes = v),
            ),
          ),
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
              color: Color(0xFF5B2EC9),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF7B3FF2),
              inactiveTrackColor: const Color(0xFF7B3FF2).withValues(alpha: 0.18),
              thumbColor: const Color(0xFF5B2EC9),
              overlayColor: const Color(0xFF7B3FF2).withValues(alpha: 0.16),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF4A2F8F))),
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
              gradient: isSelected
                  ? const LinearGradient(colors: [Color(0xFFB57BFF), Color(0xFF7B3FF2)])
                  : null,
              color: isSelected ? null : const Color(0xFFF1ECFF),
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? const [BoxShadow(color: Color(0xFF4F1FB0), offset: Offset(0, 3))]
                  : null,
            ),
            child: Text(
              labelBuilder(v),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : const Color(0xFF4A2F8F),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
