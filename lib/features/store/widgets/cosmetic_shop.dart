import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/cosmetics/cosmetic_catalog.dart';
import '../../../data/models/player_profile.dart';
import '../../../providers/player_profile_provider.dart';
import '../../game/widgets/connector_painter.dart';
import '../../game/widgets/letter_tile.dart';
import '../store_screen.dart';
import 'store_kit.dart';

/// עיצובים: כל כרטיס מציג תצוגה חיה של העיצוב עם האריחים האמיתיים של
/// המשחק, כדי לראות בדיוק מה מקבלים לפני שקונים.
class CosmeticShop extends StatelessWidget {
  final PlayerProfile profile;
  final void Function(Offset at, {bool coinRain}) onCelebrate;
  final VoidCallback onNeedCoins;

  const CosmeticShop({super.key, required this.profile, required this.onCelebrate, required this.onNeedCoins});

  @override
  Widget build(BuildContext context) {
    final letterBase = CosmeticCatalog.boards.firstWhere(
      (b) => b.id == profile.boardSkinId,
      orElse: () => CosmeticCatalog.boards.first,
    );
    final letterSkin = CosmeticCatalog.letters.firstWhere(
      (l) => l.id == profile.letterSkinId,
      orElse: () => CosmeticCatalog.letters.first,
    );

    Widget section(String title, IconData icon, List<Widget> cards) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(
            children: [
              Icon(icon, color: StorePalette.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        _Grid(children: cards),
        const SizedBox(height: 12),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('לוח', Icons.grid_view_rounded, [
          for (final skin in CosmeticCatalog.boards)
            _CosmeticCard(
              slot: CosmeticSlot.board,
              id: skin.id,
              name: skin.nameHe,
              cost: skin.cost,
              profile: profile,
              onCelebrate: onCelebrate,
              onNeedCoins: onNeedCoins,
              preview: _BoardPreview(skin: skin, letterSkin: letterSkin),
            ),
        ]),
        section('אותיות', Icons.text_fields_rounded, [
          for (final skin in CosmeticCatalog.letters)
            _CosmeticCard(
              slot: CosmeticSlot.letter,
              id: skin.id,
              name: skin.nameHe,
              cost: skin.cost,
              profile: profile,
              onCelebrate: onCelebrate,
              onNeedCoins: onNeedCoins,
              preview: _LettersPreview(skin: skin, board: letterBase),
            ),
        ]),
        section('סימון', Icons.gesture_rounded, [
          for (final skin in CosmeticCatalog.markers)
            _CosmeticCard(
              slot: CosmeticSlot.marker,
              id: skin.id,
              name: skin.nameHe,
              cost: skin.cost,
              profile: profile,
              onCelebrate: onCelebrate,
              onNeedCoins: onNeedCoins,
              preview: _MarkerPreview(skin: skin, board: letterBase, letterSkin: letterSkin),
            ),
        ]),
        NeedCoinsHint(onTap: onNeedCoins),
      ],
    );
  }
}

/// רשת של שני כרטיסים בשורה (בלי גלילה פנימית).
class _Grid extends StatelessWidget {
  final List<Widget> children;

  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// דרגת "נדירות" לפי מחיר - צבע לתגית ולמסגרת.
({String label, List<Color> colors}) _tierFor(int cost) {
  if (cost == 0) return (label: 'בסיסי', colors: const [Color(0xFF9AA5B8), Color(0xFF6E7A90)]);
  if (cost < 500) return (label: 'מיוחד', colors: const [Color(0xFF4FC3F7), Color(0xFF1E88E5)]);
  if (cost < 800) return (label: 'נדיר', colors: const [Color(0xFFB388FF), Color(0xFF7C4DFF)]);
  return (label: 'אגדי', colors: const [Color(0xFFFFD54F), Color(0xFFFF8F00)]);
}

class _CosmeticCard extends ConsumerStatefulWidget {
  final CosmeticSlot slot;
  final String id;
  final String name;
  final int cost;
  final PlayerProfile profile;
  final Widget preview;
  final void Function(Offset at, {bool coinRain}) onCelebrate;
  final VoidCallback onNeedCoins;

  const _CosmeticCard({
    required this.slot,
    required this.id,
    required this.name,
    required this.cost,
    required this.profile,
    required this.preview,
    required this.onCelebrate,
    required this.onNeedCoins,
  });

  @override
  ConsumerState<_CosmeticCard> createState() => _CosmeticCardState();
}

class _CosmeticCardState extends ConsumerState<_CosmeticCard> {
  final _shake = GlobalKey<ShakeBoxState>();
  bool _busy = false;

  bool get _owned => widget.cost == 0 || widget.profile.ownedFor(widget.slot.name).contains(widget.id);

  bool get _equipped => switch (widget.slot) {
    CosmeticSlot.board => widget.profile.boardSkinId == widget.id,
    CosmeticSlot.letter => widget.profile.letterSkinId == widget.id,
    CosmeticSlot.marker => widget.profile.markerSkinId == widget.id,
  };

  Future<void> _tap() async {
    if (_equipped || _busy) return;
    _busy = true;
    final wasOwned = _owned;
    await buyWithCoins(
      context: context,
      ref: ref,
      shakeKey: _shake,
      onCelebrate: widget.onCelebrate,
      onNeedCoins: widget.onNeedCoins,
      successText: wasOwned ? 'העיצוב "${widget.name}" מצויד' : 'העיצוב "${widget.name}" שלכם! ✨',
      purchase: () async {
        final ok = await ref
            .read(playerProfileProvider.notifier)
            .buyOrEquipCosmetic(slot: widget.slot, id: widget.id, cost: widget.cost);
        if (ok && !wasOwned) {
          AnalyticsService.instance.spendVirtualCurrency(
            currency: 'coins',
            value: widget.cost,
            itemName: 'skin_${widget.slot.name}_${widget.id}',
          );
        }
        return ok;
      },
    );
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(widget.cost);
    final equipped = _equipped;
    final owned = _owned;
    final affordable = widget.profile.coins >= widget.cost;

    final Widget button;
    if (equipped) {
      button = const PriceButton(label: 'מצויד ✓', colors: [Color(0xFF5BE3B0), Color(0xFF1FB86A)]);
    } else if (owned) {
      button = const PriceButton(label: 'הפעילו', colors: [Color(0xFFB57BFF), Color(0xFF7B3FF2)]);
    } else {
      button = PriceButton(label: '${widget.cost}', coins: true, enabled: affordable);
    }

    return ShakeBox(
      key: _shake,
      child: TiltCard(
        maxTilt: 0.12,
        onTap: _tap,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: equipped ? const [Color(0xFF5BE3B0), Color(0xFF1FB86A)] : tier.colors),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21.5),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [StorePalette.card, StorePalette.cardTint],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [tier.colors.first.withValues(alpha: 0.18), tier.colors.last.withValues(alpha: 0.32)],
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: FittedBox(fit: BoxFit.scaleDown, child: widget.preview),
                    ),
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: tier.colors),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tier.label,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (equipped)
                      const PositionedDirectional(
                        top: 4,
                        end: 4,
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF1FB86A), size: 22),
                      )
                    else if (!owned)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: Icon(Icons.lock_rounded, color: StorePalette.muted.withValues(alpha: 0.8), size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: StorePalette.ink, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 8),
                button,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  final BoardSkin skin;
  final LetterSkin letterSkin;

  const _BoardPreview({required this.skin, required this.letterSkin});

  static const _letters = ['מ', 'ל', 'ה', 'צ', 'א', 'ת', 'י', 'ב', 'ש'];

  @override
  Widget build(BuildContext context) {
    const tile = 24.0;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: skin.backdropColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 3; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < 3; c++)
                  Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: LetterTile(
                      letter: _letters[r * 3 + c],
                      size: tile,
                      boardTileColor: skin.tileColor,
                      letterSkin: letterSkin.tileOverride == null ? letterSkin : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LettersPreview extends StatelessWidget {
  final LetterSkin skin;
  final BoardSkin board;

  const _LettersPreview({required this.skin, required this.board});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final letter in const ['א', 'ב', 'ג'])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: LetterTile(letter: letter, size: 40, letterSkin: skin, boardTileColor: board.tileColor),
          ),
      ],
    );
  }
}

class _MarkerPreview extends StatelessWidget {
  final MarkerSkin skin;
  final BoardSkin board;
  final LetterSkin letterSkin;

  const _MarkerPreview({required this.skin, required this.board, required this.letterSkin});

  static const _tile = 32.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    // ארבעה אריחים בזיגזג, והסימון עובר דרך המרכזים.
    const positions = [Offset(0, 1), Offset(1, 0), Offset(2, 1), Offset(3, 0)];
    const step = _tile + _gap;
    final centers = [for (final p in positions) Offset(p.dx * step + _tile / 2, p.dy * (_tile * 0.9) + _tile / 2)];
    return SizedBox(
      width: step * 3 + _tile,
      height: _tile * 1.9,
      child: Stack(
        children: [
          for (var i = 0; i < positions.length; i++)
            Positioned(
              left: positions[i].dx * step,
              top: positions[i].dy * (_tile * 0.9),
              child: LetterTile(
                letter: const ['ש', 'ל', 'ו', 'ם'][i],
                size: _tile,
                state: TileVisualState.selected,
                boardTileColor: board.tileColor,
                letterSkin: letterSkin,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ConnectorPainter(points: centers, style: skin.style, markerColor: skin.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
