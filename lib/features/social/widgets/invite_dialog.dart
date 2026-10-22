import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/candy_button.dart';
import '../../../core/ui/game_dialog.dart';
import '../models/social_models.dart';
import 'presence_avatar.dart';

/// החלון הקופץ שמופיע כשחבר/ה מזמין/ה אותך למשחק - בהשראת ה-"Friendly
/// Battle" של Clash Royale: האוואטאר של המזמין/ה בתוך טבעת ספירה לאחור,
/// פרטי המשחק, וכפתור גדול להצטרפות מיידית.
enum InviteAnswer { accept, decline, reportOrBlock }

Future<InviteAnswer> showInviteDialog(BuildContext context, GameInvite invite) async {
  final result = await showGameDialog<InviteAnswer>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _InviteDialog(invite: invite),
  );
  return result ?? InviteAnswer.decline;
}

class _InviteDialog extends StatefulWidget {
  final GameInvite invite;
  const _InviteDialog({required this.invite});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (!widget.invite.isActive()) {
        Navigator.of(context).pop(InviteAnswer.decline);
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final remaining = invite.remaining();
    final fraction = remaining.inMilliseconds / GameInvite.lifetime.inMilliseconds;

    return GameDialog(
      title: 'הזמנה למשחק! ⚔️',
      ribbon: CandyPalette.purple,
      hero: Column(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: CircularProgressIndicator(
                    value: fraction.clamp(0, 1),
                    strokeWidth: 6,
                    backgroundColor: const Color(0xFFEDE6FF),
                    valueColor: AlwaysStoppedAnimation(
                      fraction > 0.3 ? const Color(0xFF7B3FF2) : const Color(0xFFFF4F8B),
                    ),
                  ),
                ),
                PresenceAvatar(
                  avatarId: invite.fromAvatarId,
                  photoUrl: invite.fromPhotoUrl,
                  status: PresenceStatus.online,
                  size: 88,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            invite.fromName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2B2440)),
          ),
          const Text(
            'מזמין/ה אותך לדו-קרב מילים!',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF6B5E8F)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _InfoChip(icon: Icons.grid_view_rounded, label: 'לוח ${invite.gridSize}×${invite.gridSize}'),
              _InfoChip(icon: Icons.timer_rounded, label: '${invite.roundSeconds} שנ׳'),
              _InfoChip(icon: Icons.monetization_on_rounded, label: 'כניסה ${invite.entryFee}'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ההזמנה בתוקף עוד ${remaining.inSeconds} שניות',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A80A8), fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        CandyButton(
          label: 'הצטרפות למשחק',
          icon: Icons.sports_esports_rounded,
          palette: CandyPalette.green,
          height: 58,
          onPressed: () => Navigator.of(context).pop(InviteAnswer.accept),
        ),
        CandyButton(
          label: 'לא עכשיו',
          palette: CandyPalette.white,
          height: 48,
          fontSize: 16,
          onPressed: () => Navigator.of(context).pop(InviteAnswer.decline),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(InviteAnswer.reportOrBlock),
          icon: const Icon(Icons.flag_rounded, size: 18, color: Color(0xFF8A80A8)),
          label: const Text(
            'דיווח / חסימה',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A80A8)),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7B3FF2)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF4A2F8F))),
        ],
      ),
    );
  }
}
