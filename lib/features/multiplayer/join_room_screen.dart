import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/room_models.dart';

/// מסך "הצטרפות לחדר" - הזנת שם/כינוי וקוד חדר בן 5 ספרות שהתקבל
/// ממנהל/ת החדר (ראו create_room_screen.dart). אחרי הזנת הקוד מוצגים
/// דמי הכניסה והקופה, ומי שאין לו/ה מספיק מטבעות לא יכול/ה להיכנס.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  late final TextEditingController _nameController;
  final _codeController = TextEditingController();
  bool _isJoining = false;
  bool _isFetching = false;
  String? _error;
  String? _previewedCode;
  GameRoom? _preview;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider).valueOrNull;
    final defaultName = profile != null && profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'את/ה';
    _nameController = TextEditingController(text: defaultName);
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  int get _myCoins => ref.read(playerProfileProvider).valueOrNull?.coins ?? 0;

  void _onCodeChanged() {
    final code = _codeController.text.trim();
    if (code.length != 5) {
      if (_preview != null || _previewedCode != null) {
        setState(() {
          _preview = null;
          _previewedCode = null;
          _error = null;
        });
      }
      return;
    }
    if (code == _previewedCode || _isFetching) return;
    _fetchPreview(code);
  }

  Future<void> _fetchPreview(String code) async {
    setState(() {
      _isFetching = true;
      _previewedCode = code;
      _error = null;
    });
    try {
      final room = await ref.read(multiplayerRepositoryProvider).fetchRoom(code);
      if (!mounted || _codeController.text.trim() != code) return;
      setState(() {
        _preview = room;
        _isFetching = false;
      });
    } catch (e) {
      if (!mounted || _codeController.text.trim() != code) return;
      setState(() {
        _preview = null;
        _isFetching = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _join() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'אנא הזינו שם/כינוי.');
      return;
    }
    if (code.length != 5) {
      setState(() => _error = 'קוד החדר מורכב מ-5 ספרות.');
      return;
    }

    var room = _preview;
    if (room == null || room.roomCode != code) {
      setState(() {
        _isJoining = true;
        _error = null;
      });
      try {
        room = await ref.read(multiplayerRepositoryProvider).fetchRoom(code);
        if (!mounted) return;
        setState(() => _preview = room);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isJoining = false;
          _error = _friendlyError(e);
        });
        return;
      }
    }

    final fee = room.entryFee;
    if (_myCoins < fee) {
      setState(() {
        _isJoining = false;
        _error = 'אין מספיק מטבעות (צריך $fee, יש $_myCoins).';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    final spent = await ref.read(playerProfileProvider.notifier).spendCoins(fee);
    if (!spent) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _error = 'אין מספיק מטבעות (צריך $fee).';
      });
      return;
    }

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final joined = await repo.joinRoom(roomCode: code, displayName: name);
      if (!mounted) return;
      context.pushReplacement('/multiplayer/online/room/${joined.roomCode}');
    } catch (e) {
      await ref.read(playerProfileProvider.notifier).addCoins(fee);
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    // StateError.toString() מחזיר "Bad state: <הודעה>" - חושפים רק את
    // ההודעה הידידותית שכתבנו ב-repository (ראו firestore_multiplayer_repository.dart).
    final message = e.toString().replaceFirst('Bad state: ', '');
    return message.isEmpty ? 'לא הצלחנו להצטרף לחדר. נסו שוב.' : message;
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(playerProfileProvider).valueOrNull?.coins ?? 0;
    final preview = _preview;
    final canJoin = !_isJoining &&
        !_isFetching &&
        _codeController.text.trim().length == 5 &&
        preview != null &&
        coins >= preview.entryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('הצטרפות לחדר'),
        backgroundColor: AppColors.primaryDark,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: MascotWidget(mood: MascotMood.happy, size: 90)),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'הזינו את הקוד שקיבלתם ממנהל/ת החדר',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('שם/כינוי שלך',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('קוד החדר', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    maxLength: 5,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.background.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      hintText: '12345',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isFetching) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
          if (preview != null) ...[
            const SizedBox(height: 16),
            _EntryFeePreview(room: preview, myCoins: coins),
          ],
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
            onPressed: canJoin ? _join : (_isJoining ? null : (_preview == null ? _join : null)),
            child: _isJoining
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('הצטרפות לחדר 🚪'),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

class _EntryFeePreview extends StatelessWidget {
  final GameRoom room;
  final int myCoins;

  const _EntryFeePreview({required this.room, required this.myCoins});

  @override
  Widget build(BuildContext context) {
    final enough = myCoins >= room.entryFee;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('דמי כניסה לחדר', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CoinStat(label: 'כניסה', value: '${room.entryFee}'),
                _CoinStat(label: 'קופה כרגע', value: '${room.pot}'),
                _CoinStat(label: 'יתרה שלך', value: '$myCoins', warn: !enough),
              ],
            ),
            if (!enough) ...[
              const SizedBox(height: 12),
              Text(
                'אין מספיק מטבעות להיכנס (צריך ${room.entryFee})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoinStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;

  const _CoinStat({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.monetization_on_rounded, color: warn ? AppColors.error : AppColors.star, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: warn ? AppColors.error : AppColors.textDark,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
