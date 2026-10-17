import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/room_models.dart';

/// מסך "הצטרפות לחדר" - הזנת שם/כינוי וקוד חדר בן 5 ספרות שהתקבל
/// ממנהל/ת החדר (ראו create_room_screen.dart). אחרי הזנת הקוד מוצגים
/// דמי הכניסה והקופה, ומי שאין לו/ה מספיק מטבעות לא יכול/ה להיכנס.
class JoinRoomScreen extends ConsumerStatefulWidget {
  /// קוד שהגיע מקישור (וואטסאפ) או מהזמנה של חבר/ה - ממולא מראש.
  final String? initialCode;

  /// true = הגענו מאישור הזמנה: מצטרפים מיד ברגע שפרטי החדר נטענו.
  final bool autoJoin;

  /// דמי הכניסה שהופיעו בהזמנה. אם בחדר עצמו הם שונים, לא מצטרפים
  /// אוטומטית - השחקן/ית רואה את הסכום האמיתי ומאשר/ת בעצמו/ה.
  final int? expectedFee;

  const JoinRoomScreen({super.key, this.initialCode, this.autoJoin = false, this.expectedFee});

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
  bool _autoJoinPending = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider).valueOrNull;
    final defaultName = profile != null && profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'את/ה';
    _nameController = TextEditingController(text: defaultName);
    _codeController.addListener(_onCodeChanged);
    final code = widget.initialCode?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (code.length == 5) {
      _autoJoinPending = widget.autoJoin;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeController.text = code;
      });
    }
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
      if (_autoJoinPending) {
        _autoJoinPending = false;
        final expected = widget.expectedFee;
        if (expected != null && room.entryFee != expected) {
          setState(() => _error = 'דמי הכניסה בחדר הם ${room.entryFee} מטבעות (לא $expected כמו בהזמנה). '
              'לחצו "הצטרפות לחדר" כדי לאשר.');
          return;
        }
        final profile = await ref.read(playerProfileProvider.notifier).ensureLoaded();
        if (!mounted) return;
        if (profile.displayName.trim().isNotEmpty && _nameController.text.trim() == 'את/ה') {
          _nameController.text = profile.displayName.trim();
        }
        await _join();
      }
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
    if (spent) {
      AnalyticsService.instance.spendVirtualCurrency(currency: 'coins', value: fee, itemName: 'room_entry_fee');
    }
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
      final profile = ref.read(playerProfileProvider).valueOrNull;
      final joined = await repo.joinRoom(
        roomCode: code,
        displayName: name,
        avatarId: profile?.avatarId,
        photoUrl: ref.read(authStateProvider).valueOrNull?.photoUrl,
      );
      if (!mounted) return;
      context.pushReplacement('/multiplayer/online/room/${joined.roomCode}');
    } catch (e) {
      await ref.read(playerProfileProvider.notifier).addCoins(fee);
      AnalyticsService.instance.earnVirtualCurrency(currency: 'coins', value: fee, source: 'other', item: 'room_fee_refund');
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    // רק הודעות StateError הן הודעות ידידותיות שכתבנו ב-repository (ראו
    // firestore_multiplayer_repository.dart). שגיאות אחרות לא מוצגות כלשונן.
    if (e is StateError && e.message.isNotEmpty) return e.message;
    return 'לא הצלחנו להצטרף לחדר. נסו שוב.';
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

    return GameScaffold(
      colors: const [Color(0xFFFFB259), Color(0xFFFF7A45), Color(0xFFE8456B)],
      header: GameHeader(
        title: 'הצטרפות לחדר',
        onBack: () => context.canPop() ? context.pop() : context.go('/play/friends'),
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          CandyButton(
            label: 'הצטרפות לחדר 🚪',
            palette: CandyPalette.green,
            height: 62,
            loading: _isJoining,
            onPressed: canJoin ? _join : (_isJoining ? null : (_preview == null ? _join : null)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          const Center(child: MascotWidget(mood: MascotMood.happy, size: 84)),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'הזינו את הקוד שקיבלתם ממנהל/ת החדר',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          _WhiteCard(
            title: 'קוד החדר',
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                maxLength: 5,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: Color(0xFFC94A1C),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFFFF3EA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '12345',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _WhiteCard(
            title: 'שם/כינוי שלך',
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              maxLength: 16,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFFFF3EA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_isFetching) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
          if (preview != null) ...[
            const SizedBox(height: 14),
            _EntryFeePreview(room: preview, myCoins: coins)
                .animate()
                .fadeIn(duration: 250.ms)
                .scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutBack),
          ],
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _WhiteCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF7A3A12))),
          const SizedBox(height: 10),
          child,
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
