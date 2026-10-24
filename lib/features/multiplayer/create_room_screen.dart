import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/feedback/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/segmented_setting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/social_provider.dart';
import '../profile/widgets/avatar_widget.dart';
import '../social/friends_screen.dart';
import '../store/widgets/store_kit.dart';
import 'models/room_models.dart';

/// "חדר חדש" למשחק מול חברים - מסך אחד בלי גלילה:
/// * למעלה **זירה**: הדמות שלך (מארח/ת, עם כתר) מול כיסאות פנויים שמהבהבים
///   (או החבר/ה שמזמינים), ובאמצע **קופה תלת-ממדית** שגדלה עם ההימור.
/// * **הימור**: ארבעה מטבעות - 50 / 100 / 200 / 500. מטבע שאין מספיק בשבילו
///   נעול. הזוכה לוקח/ת את כל הקופה.
/// * **הגדרות** בבוררים מחליקים: לוח, זמן, סבבים, יעד, וזמן הצטרפות.
///
/// הכינוי לקוח מהפרופיל ואי אפשר לשנות אותו כאן.
class CreateRoomScreen extends ConsumerStatefulWidget {
  /// אם נפתח מ"הזמנה למשחק" של חבר/ה - ההזמנה נשלחת אוטומטית ברגע שהחדר נוצר.
  final String? inviteFriendUid;
  final String? inviteFriendName;

  const CreateRoomScreen({super.key, this.inviteFriendUid, this.inviteFriendName});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  int _gridSize = 5;
  int _roundSeconds = 90;
  int _targetScore = 0;
  int _totalRounds = 1;
  int _entryFee = GameRoom.allowedEntryFees.first;
  int _joinWindowMinutes = 10;
  bool _isCreating = false;
  String? _error;

  int get _myCoins => ref.read(playerProfileProvider).valueOrNull?.coins ?? 0;

  String _myName() {
    final name = ref.read(playerProfileProvider).valueOrNull?.displayName.trim() ?? '';
    return name.isEmpty ? 'את/ה' : name;
  }

  bool get _hasInvite => widget.inviteFriendUid != null && widget.inviteFriendUid!.isNotEmpty;

  void _pick(VoidCallback change) {
    Haptics.selection();
    setState(change);
  }

  Future<void> _create() async {
    if (_myCoins < _entryFee) {
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
    AnalyticsService.instance.spendVirtualCurrency(currency: 'coins', value: _entryFee, itemName: 'room_entry_fee');

    try {
      final repo = ref.read(multiplayerRepositoryProvider);
      final room = await repo.createRoom(
        hostDisplayName: _myName(),
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
          await ref
              .read(socialRepositoryProvider)
              .sendInvite(
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
      AnalyticsService.instance.earnVirtualCurrency(
        currency: 'coins',
        value: _entryFee,
        source: 'other',
        item: 'room_fee_refund',
      );
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'לא הצלחנו ליצור חדר: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final coins = profile?.coins ?? 0;
    final canAfford = coins >= _entryFee;
    final screenH = MediaQuery.sizeOf(context).height;
    final compact = screenH < 760;
    final rowH = compact ? 31.0 : 40.0;

    return GameScaffold(
      colors: kFriendsGradient,
      header: GameHeader(
        title: 'חדר חדש',
        subtitle: _hasInvite ? 'הזמנה ל${widget.inviteFriendName ?? 'חבר/ה'}' : 'משחק מול חברים',
        onBack: () => context.canPop() ? context.pop() : context.go('/play/friends'),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.safeBottom(min: 12, extra: 6)),
        child: Column(
          children: [
            Expanded(
              child: _Arena(
                avatarId: profile?.avatarId ?? 'detective',
                photoUrl: ref.watch(authStateProvider).valueOrNull?.photoUrl,
                name: _myName(),
                stake: _entryFee,
                inviteName: _hasInvite ? (widget.inviteFriendName ?? 'חבר/ה') : null,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            _StakePicker(
              selected: _entryFee,
              coins: coins,
              compact: compact,
              onSelect: (fee) => _pick(() {
                _entryFee = fee;
                _error = null;
              }),
            ),
            SizedBox(height: compact ? 6 : 10),
            SettingsPanel(
              gap: compact ? 4 : 7,
              children: [
                SegmentedSetting<int>(
                  height: rowH,
                  icon: Icons.grid_view_rounded,
                  label: 'לוח',
                  values: const [3, 4, 5, 6, 7],
                  selected: _gridSize,
                  labelOf: (v) => '$v×$v',
                  onSelect: (v) => _pick(() => _gridSize = v),
                ),
                SegmentedSetting<int>(
                  height: rowH,
                  icon: Icons.timer_rounded,
                  label: 'זמן',
                  values: const [60, 90, 120, 180],
                  selected: _roundSeconds,
                  labelOf: (v) => v % 60 == 0 ? '${v ~/ 60} דק׳' : '$v שנ׳',
                  onSelect: (v) => _pick(() => _roundSeconds = v),
                ),
                SegmentedSetting<int>(
                  height: rowH,
                  icon: Icons.repeat_rounded,
                  label: 'סבבים',
                  values: const [1, 3, 5],
                  selected: _totalRounds,
                  labelOf: (v) => v == 1 ? 'אחד' : '$v',
                  onSelect: (v) => _pick(() => _totalRounds = v),
                ),
                SegmentedSetting<int>(
                  height: rowH,
                  icon: Icons.flag_rounded,
                  label: 'יעד',
                  values: const [0, 150, 300, 600],
                  selected: _targetScore,
                  labelOf: (v) => v == 0 ? 'ללא' : '$v',
                  onSelect: (v) => _pick(() => _targetScore = v),
                ),
                SegmentedSetting<int>(
                  height: rowH,
                  icon: Icons.hourglass_top_rounded,
                  label: 'הצטרפות',
                  values: const [5, 10, 20],
                  selected: _joinWindowMinutes,
                  labelOf: (v) => '$v דק׳',
                  onSelect: (v) => _pick(() => _joinWindowMinutes = v),
                ),
              ],
            ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            SizedBox(height: compact ? 8 : 12),
            canAfford
                ? CandyButton(
                    label: _hasInvite ? 'יצירה ושליחת הזמנה' : 'יצירת חדר',
                    icon: Icons.vpn_key_rounded,
                    palette: CandyPalette.green,
                    height: compact ? 50 : 60,
                    fontSize: 21,
                    loading: _isCreating,
                    onPressed: _isCreating ? null : _create,
                  )
                : CandyButton(
                    label: _entryFee - coins == 1 ? 'חסר מטבע אחד' : 'חסרים ${_entryFee - coins} מטבעות',
                    subtitle: 'לחנות',
                    icon: Icons.storefront_rounded,
                    palette: CandyPalette.gold,
                    height: compact ? 50 : 60,
                    fontSize: 18,
                    onPressed: () => context.push('/store?from=room_no_coins'),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- זירה

/// הדמות שלך (עם כתר "מארח/ת") מול כיסאות פנויים, וקופה מרחפת באמצע.
class _Arena extends StatefulWidget {
  final String avatarId;
  final String? photoUrl;
  final String name;
  final int stake;
  final String? inviteName;

  const _Arena({
    required this.avatarId,
    required this.photoUrl,
    required this.name,
    required this.stake,
    this.inviteName,
  });

  @override
  State<_Arena> createState() => _ArenaState();
}

class _ArenaState extends State<_Arena> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  String get _potArt => switch (widget.stake) {
    <= 50 => StoreArt.coinsSmall,
    <= 100 => StoreArt.coinsMedium,
    _ => StoreArt.coinsLarge,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final me = (h * 0.5).clamp(56.0, 120.0);
        final seat = (me * 0.62).clamp(40.0, 74.0);
        final pot = (h * 0.62).clamp(70.0, 150.0);
        // שני כיסאות בשורה (ועוד אחד מתחת) בתוך רוחב הצד.
        final side = (c.maxWidth - pot) / 2;
        final seatFit = math.min(seat, (side - 10) / 2);
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value * math.pi * 2;
            // בזירה נמוכה מאוד (מסך קטן / טקסט מוגדל) הכל מתכווץ יחד.
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: c.maxWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // אני - המארח/ת.
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              Transform.translate(
                                offset: Offset(0, math.sin(t) * 3),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: StorePalette.gold.withValues(alpha: 0.55), blurRadius: 22),
                                    ],
                                  ),
                                  child: AvatarWidget(avatarId: widget.avatarId, photoUrl: widget.photoUrl, size: me),
                                ),
                              ),
                              Positioned(
                                top: -me * 0.22,
                                child: Transform.rotate(
                                  angle: -0.18 + math.sin(t * 2) * 0.05,
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    color: StorePalette.gold,
                                    size: me * 0.36,
                                    shadows: const [
                                      Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _Tag(text: widget.name, sub: 'מארח/ת', colors: const [Color(0xFFFFB259), Color(0xFFFF7A45)]),
                        ],
                      ),
                    ),
                    // הקופה.
                    SizedBox(
                      width: pot,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            transitionBuilder: (child, a) => ScaleTransition(
                              scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                              child: child,
                            ),
                            child: FloatingArt(key: ValueKey(_potArt), asset: _potArt, size: pot * 0.82, amplitude: 4),
                          ),
                          _PotLabel(stake: widget.stake),
                        ],
                      ),
                    ),
                    // החברים: כיסאות פנויים / המוזמן/ת.
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.inviteName != null)
                            _Seat(size: math.min(me * 0.9, side - 8), pulse: t, invited: true)
                          else
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (var i = 0; i < 3; i++) _Seat(size: seatFit, pulse: t + i * 1.4)],
                            ),
                          const SizedBox(height: 6),
                          _Tag(
                            text: widget.inviteName ?? 'חברים',
                            sub: widget.inviteName != null ? 'מוזמן/ת' : 'עד 7 מצטרפים',
                            colors: const [Color(0xFFB57BFF), Color(0xFF7B3FF2)],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Seat extends StatelessWidget {
  final double size;
  final double pulse;
  final bool invited;

  const _Seat({required this.size, required this.pulse, this.invited = false});

  @override
  Widget build(BuildContext context) {
    final p = 0.5 + 0.5 * math.sin(pulse * 1.5);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14 + p * 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45 + p * 0.4), width: 2.5),
        boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: p * 0.35), blurRadius: 12)],
      ),
      child: Icon(
        invited ? Icons.mark_email_unread_rounded : Icons.person_add_alt_1_rounded,
        color: Colors.white.withValues(alpha: 0.75 + p * 0.25),
        size: size * 0.45,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final String sub;
  final List<Color> colors;

  const _Tag({required this.text, required this.sub, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          Text(
            sub,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PotLabel extends StatelessWidget {
  final int stake;

  const _PotLabel({required this.stake});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: StorePalette.gold, size: 15),
            const SizedBox(width: 3),
            TweenAnimationBuilder<double>(
              tween: Tween(end: stake.toDouble()),
              duration: const Duration(milliseconds: 500),
              builder: (context, v, _) => Text(
                'הזוכה לוקח ${v.round()}×שחקנים',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- הימור

/// ארבעה מטבעות זהב להימור. מטבע שאין מספיק בשבילו - אפור עם מנעול.
class _StakePicker extends StatelessWidget {
  final int selected;
  final int coins;
  final bool compact;
  final ValueChanged<int> onSelect;

  const _StakePicker({required this.selected, required this.coins, required this.compact, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 10, compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.casino_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'על כמה משחקים?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              const CoinGlyph(size: 16),
              const SizedBox(width: 4),
              Text(
                '$coins',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Row(
            children: [
              for (final fee in GameRoom.allowedEntryFees)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _StakeCoin(
                      fee: fee,
                      selected: fee == selected,
                      affordable: coins >= fee,
                      size: compact ? 44 : 60,
                      onTap: () => onSelect(fee),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StakeCoin extends StatelessWidget {
  final int fee;
  final bool selected;
  final bool affordable;
  final double size;
  final VoidCallback onTap;

  const _StakeCoin({
    required this.fee,
    required this.selected,
    required this.affordable,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = affordable
        ? const [Color(0xFFFFF0A8), Color(0xFFFFC93C), Color(0xFFFF9F1C)]
        : const [Color(0xFFE5E1EE), Color(0xFFC9C2D8), Color(0xFFA9A1BD)];
    final rim = affordable ? const Color(0xFFC77F00) : const Color(0xFF8A829E);
    return Semantics(
      button: true,
      selected: selected,
      label: '$fee מטבעות${affordable ? '' : ' - אין מספיק'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // עובי המטבע (תלת-ממד) + זוהר כשנבחר.
                Container(
                  width: size,
                  height: size,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rim,
                    boxShadow: selected
                        ? [BoxShadow(color: StorePalette.gold.withValues(alpha: 0.8), blurRadius: 18, spreadRadius: 2)]
                        : null,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -2),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(center: const Alignment(-0.35, -0.4), colors: colors),
                      border: Border.all(color: selected ? Colors.white : rim, width: selected ? 3 : 2),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$fee',
                              style: TextStyle(
                                color: affordable ? const Color(0xFF6B3A00) : const Color(0xFF6E6684),
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                height: 1,
                              ),
                            ),
                            Icon(
                              affordable ? Icons.star_rounded : Icons.lock_rounded,
                              size: 14,
                              color: affordable ? const Color(0xFFB36B00) : const Color(0xFF6E6684),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ).animate().scale(curve: Curves.elasticOut, duration: 500.ms),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
