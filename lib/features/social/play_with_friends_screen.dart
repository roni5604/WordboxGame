import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/pressable.dart';
import '../../providers/social_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'friends_screen.dart';
import 'models/social_models.dart';
import 'social_actions.dart';
import 'widgets/presence_avatar.dart';

/// "שחק נגד חברים" - נקודת הכניסה למשחק אמיתי מול חברים: מי מחובר עכשיו
/// (עם הזמנה בלחיצה אחת), יצירת חדר, הצטרפות עם קוד, וקישור לרשימת החברים.
class PlayWithFriendsScreen extends ConsumerWidget {
  const PlayWithFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const <FriendEntry>[];
    final incoming = ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;
    final now = DateTime.now();
    final online = friends.where((f) => f.profile.isOnline(now)).toList()
      ..sort((a, b) => a.profile.effectiveStatus(now).index.compareTo(b.profile.effectiveStatus(now).index));

    return GameScaffold(
      colors: kFriendsGradient,
      header: GameHeader(
        title: 'שחק נגד חברים',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, context.safeBottom(min: 24, extra: 20)),
        children: [
          const Center(child: MascotWidget(mood: MascotMood.excited, size: 92))
              .animate()
              .scaleXY(begin: 0.6, end: 1, duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 6),
          const Text(
            'אותו לוח לכולם, בזמן אמת.\nמי שמוצא/ת הכי הרבה מילים - מנצח/ת!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (!AppConfig.multiplayerEnabled)
            const _Notice(text: 'משחק אונליין מול חברים יחזור בקרוב 🚀')
          else ...[
            _OnlineFriendsStrip(online: online).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            CandyButton(
              label: 'יצירת חדר והזמנת חברים',
              subtitle: 'קבלו קישור לוואטסאפ או הזמינו חבר מחובר',
              icon: Icons.add_home_rounded,
              palette: CandyPalette.green,
              height: 72,
              fontSize: 19,
              onPressed: () => context.push('/multiplayer/online/create'),
            ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 12),
            CandyButton(
              label: 'הצטרפות עם קוד',
              subtitle: 'קיבלתם קוד חדר מחבר/ה?',
              icon: Icons.vpn_key_rounded,
              palette: CandyPalette.orange,
              height: 66,
              fontSize: 18,
              onPressed: () => context.push('/multiplayer/online/join'),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 12),
            CandyButton(
              label: 'החברים שלי',
              subtitle: friends.isEmpty ? 'הוסיפו חברים עם קוד חבר' : '${friends.length} חברים · ${online.length} מחוברים',
              icon: Icons.people_alt_rounded,
              palette: CandyPalette.white,
              height: 66,
              fontSize: 18,
              badgeCount: incoming,
              onPressed: () => context.push('/friends'),
            ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.15, end: 0),
          ],
        ],
      ),
    );
  }
}

class _OnlineFriendsStrip extends ConsumerWidget {
  final List<FriendEntry> online;
  const _OnlineFriendsStrip({required this.online});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF2EDB5B), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                online.isEmpty ? 'אין חברים מחוברים כרגע' : 'מחוברים עכשיו (${online.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (online.isEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'שלחו לחברים קישור לחדר בוואטסאפ - הם יכולים להצטרף גם מהדפדפן!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                CandyIconButton(
                  icon: Icons.person_add_alt_1_rounded,
                  palette: CandyPalette.white,
                  tooltip: 'הוספת חבר',
                  onPressed: () => showAddFriendDialog(context),
                ),
              ],
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: online.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = online[i].profile;
                  return Pressable(
                    onTap: () => SocialActions.inviteToNewRoom(context, uid: p.uid, name: p.displayName),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          PresenceAvatar.of(p, size: 56),
                          const SizedBox(height: 4),
                          Text(
                            p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33C24D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'הזמנה',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}
