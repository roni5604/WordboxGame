import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/social_provider.dart';
import '../game/widgets/mascot_widget.dart';
import '../profile/widgets/avatar_widget.dart';
import 'models/social_models.dart';
import 'services/social_repository.dart';
import 'social_actions.dart';
import 'widgets/presence_avatar.dart';

const kFriendsGradient = [Color(0xFF9D50FF), Color(0xFF5B5BF0), Color(0xFF3A7BFF)];

/// מסך החברים: הכרטיס שלי עם קוד החבר, רשימת חברים עם נוכחות חיה
/// ומאזן ראש בראש, בקשות חברות (נכנסות ויוצאות), ודירוג מול החברים.
class FriendsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const FriendsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  late int _tab = widget.initialTab.clamp(0, 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = await ref.read(playerProfileProvider.notifier).ensureLoaded();
      final name = profile.displayName;
      final repo = ref.read(socialRepositoryProvider);
      if (repo.isAvailable && (name.trim().isEmpty || name == 'שחקן/ית') && mounted) {
        await SocialActions.editDisplayName(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(socialRepositoryProvider);
    final incoming = ref.watch(incomingFriendRequestsProvider).valueOrNull ?? const [];
    final friendsCount = ref.watch(friendsProvider).valueOrNull?.length ?? 0;

    return GameScaffold(
      colors: kFriendsGradient,
      header: GameHeader(
        title: 'חברים',
        subtitle: friendsCount == 0 ? null : '$friendsCount חברים · ${ref.watch(onlineFriendsCountProvider)} מחוברים',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: !repo.isAvailable
          ? const _OfflineState()
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _MyCard()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: _SegmentedTabs(
                      index: _tab,
                      labels: const ['החברים שלי', 'בקשות', 'דירוג'],
                      badges: [0, incoming.length, 0],
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, context.safeBottom(min: 24, extra: 24)),
                  sliver: SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: switch (_tab) {
                        0 => const _FriendsTab(key: ValueKey('friends')),
                        1 => const _RequestsTab(key: ValueKey('requests')),
                        _ => const _LeaderboardTab(key: ValueKey('leaderboard')),
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// הכרטיס שלי
// -----------------------------------------------------------------------------

class _MyCard extends ConsumerWidget {
  const _MyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final auth = ref.watch(authStateProvider).valueOrNull;
    final uid = ref.watch(socialUidProvider).valueOrNull;
    final code = uid == null ? '······' : SocialRepository.friendCodeFor(uid);
    final isGuest = auth == null || auth.isAnonymous;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                PresenceAvatar(
                  avatarId: profile?.avatarId ?? 'detective',
                  photoUrl: auth?.photoUrl,
                  status: PresenceStatus.online,
                  size: 54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Pressable(
                        onTap: () => SocialActions.editDisplayName(context, ref),
                        pressedScale: 0.97,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                profile?.displayName ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textDark),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_rounded, size: 17, color: Color(0xFF9D8FC4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.star, size: 17),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${profile?.totalStars ?? 0} כוכבים · שלב ${profile?.highestUnlockedLevel ?? 1}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B5E8F), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 122,
                  child: CandyButton(
                    label: 'הוספה',
                    icon: Icons.person_add_alt_1_rounded,
                    palette: CandyPalette.purple,
                    height: 44,
                    fontSize: 15,
                    radius: 16,
                    onPressed: () => showAddFriendDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCD0FF), width: 1.5),
              ),
              child: Row(
                children: [
                  const Text(
                    'הקוד שלי',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF7B6CA8)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Color(0xFF5B2EC9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CandyIconButton(
                    icon: Icons.copy_rounded,
                    size: 38,
                    tooltip: 'העתקה',
                    onPressed: uid == null ? null : () => SocialActions.copyFriendCode(context, code),
                  ),
                  const SizedBox(width: 6),
                  CandyIconButton(
                    icon: Icons.ios_share_rounded,
                    size: 38,
                    palette: CandyPalette.green,
                    tooltip: 'שיתוף הקוד',
                    onPressed: uid == null ? null : () => SocialActions.shareMyFriendCode(context, ref, whatsApp: false),
                  ),
                ],
              ),
            ),
            if (isGuest) ...[
              const SizedBox(height: 10),
              Pressable(
                onTap: () => context.push('/auth'),
                pressedScale: 0.98,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Color(0xFFFF9800)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'התחברו כדי לשמור את החברים וההתקדמות בכל מכשיר',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF7A4A00)),
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded, color: Color(0xFFFF9800)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

// -----------------------------------------------------------------------------
// טאבים
// -----------------------------------------------------------------------------

class _SegmentedTabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final List<int> badges;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({required this.index, required this.labels, required this.badges, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                start: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < labels.length; i++)
                    Expanded(
                      child: Pressable(
                        onTap: () => onChanged(i),
                        pressedScale: 0.95,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: i == index ? const Color(0xFF5B2EC9) : Colors.white,
                                ),
                                child: Text(labels[i]),
                              ),
                              if (badges[i] > 0) ...[
                                const SizedBox(width: 5),
                                CountBadge(count: badges[i]),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// טאב החברים
// -----------------------------------------------------------------------------

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendsProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorState(message: SocialActions.friendlyError(e)),
      data: (friends) {
        if (friends.isEmpty) {
          return const _EmptyState(
            title: 'עדיין אין חברים',
            message: 'שלחו לחברים את הקוד שלכם בוואטסאפ, או הוסיפו מישהו ששיחקתם איתו בחדר פרטי.',
          );
        }
        final now = DateTime.now();
        int rank(FriendEntry f) => switch (f.profile.effectiveStatus(now)) {
              PresenceStatus.online => 0,
              PresenceStatus.playing => 1,
              PresenceStatus.offline => 2,
            };
        final sorted = [...friends]
          ..sort((a, b) {
            final r = rank(a).compareTo(rank(b));
            if (r != 0) return r;
            final seenA = a.profile.lastActive ?? DateTime(2000);
            final seenB = b.profile.lastActive ?? DateTime(2000);
            return seenB.compareTo(seenA);
          });
        final online = [
          for (final f in sorted)
            if (f.profile.effectiveStatus(now) == PresenceStatus.online) f,
        ];
        return Column(
          children: [
            if (online.length >= 2) _OnlineNowStrip(friends: online),
            for (int i = 0; i < sorted.length; i++)
              _FriendTile(entry: sorted[i])
                  .animate()
                  .fadeIn(delay: (40 * i).ms, duration: 260.ms)
                  .slideX(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
          ],
        );
      },
    );
  }
}

/// "מחוברים עכשיו": שורת אוואטארים של חברים מחוברים, עם טבעת ירוקה
/// פועמת - לחיצה פותחת מיד הזמנה למשחק.
class _OnlineNowStrip extends StatelessWidget {
  final List<FriendEntry> friends;
  const _OnlineNowStrip({required this.friends});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(color: Color(0xFF3BE37A), shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 1, end: 0.35, duration: 800.ms),
              const SizedBox(width: 6),
              Text(
                'מחוברים עכשיו (${friends.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const Spacer(),
              Text(
                'לחצו כדי להזמין',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: friends.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = friends[i].profile;
                return Pressable(
                  onTap: () => SocialActions.inviteToNewRoom(context, uid: p.uid, name: p.displayName),
                  semanticLabel: 'הזמנת ${p.displayName} למשחק',
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(color: Color(0xFF3BE37A), shape: BoxShape.circle),
                          child: PresenceAvatar(
                            avatarId: p.avatarId,
                            photoUrl: p.photoUrl,
                            status: PresenceStatus.online,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (60 * i).ms).scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack);
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _FriendTile extends ConsumerWidget {
  final FriendEntry entry;
  const _FriendTile({required this.entry});

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final remove = await showConfirmDialog(
      context,
      title: 'הסרת חבר',
      message: 'להסיר את ${entry.profile.displayName} מרשימת החברים?',
      confirmLabel: 'הסרה',
      confirmPalette: CandyPalette.red,
    );
    if (!remove) return;
    try {
      await ref.read(socialRepositoryProvider).removeFriend(entry.uid);
    } catch (e) {
      if (context.mounted) GameToast.show(context, message: SocialActions.friendlyError(e), color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = entry.profile;
    final status = profile.effectiveStatus();
    final record = entry.record;
    final canInvite = status != PresenceStatus.offline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        pressedScale: 0.98,
        onLongPress: () => _showMenu(context, ref),
        onTap: () => _showFriendCard(context, entry),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: canInvite ? Border.all(color: const Color(0xFF2EDB5B).withValues(alpha: 0.6), width: 2) : null,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              PresenceAvatar.of(profile, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textDark),
                    ),
                    Text(
                      profile.presenceLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: switch (status) {
                          PresenceStatus.online => const Color(0xFF1FAE48),
                          PresenceStatus.playing => const Color(0xFFE08600),
                          PresenceStatus.offline => const Color(0xFF9A93AE),
                        },
                      ),
                    ),
                    if (record.games > 0)
                      Text(
                        'ראש בראש: ${record.wins} - ${record.losses}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7B6CA8)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: CandyButton(
                  label: 'הזמנה',
                  palette: canInvite ? CandyPalette.green : CandyPalette.white,
                  height: 42,
                  fontSize: 15,
                  radius: 16,
                  onPressed: canInvite
                      ? () => SocialActions.inviteToNewRoom(context, uid: profile.uid, name: profile.displayName)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showFriendCard(BuildContext context, FriendEntry entry) {
  final p = entry.profile;
  final r = entry.record;
  return showGameDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) => GameDialog(
        title: p.displayName,
        onClose: () => Navigator.of(dialogContext).pop(),
        hero: Column(
          children: [
            PresenceAvatar.of(p, size: 90),
            const SizedBox(height: 6),
            Text(p.presenceLabel(), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B5E8F))),
          ],
        ),
        body: Builder(
          builder: (context) {
            final me = ref.watch(playerProfileProvider).valueOrNull;
            final myStars = me?.totalStars ?? 0;
            final myLevel = me?.highestUnlockedLevel ?? 1;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  _HeadToHead(myWins: r.wins, theirWins: r.losses, games: r.games, theirName: p.displayName),
                  const SizedBox(height: 12),
                  _VsRow(label: 'כוכבים', icon: Icons.star_rounded, mine: myStars, theirs: p.totalStars),
                  _VsRow(label: 'שלב', icon: Icons.flag_rounded, mine: myLevel, theirs: p.highestLevel),
                  _VsRow(label: 'ניצחונות בתחרויות', icon: Icons.emoji_events_rounded, mine: null, theirs: p.mpWins),
                ],
              ),
            );
          },
        ),
        actions: [
          CandyButton(
            label: 'הזמנה למשחק',
            icon: Icons.sports_esports_rounded,
            palette: CandyPalette.green,
            height: 54,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SocialActions.inviteToNewRoom(context, uid: p.uid, name: p.displayName);
            },
          ),
          CandyButton(
            label: 'הסרה מהחברים',
            palette: CandyPalette.white,
            height: 46,
            fontSize: 15,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final ok = await showConfirmDialog(
                context,
                title: 'הסרת חבר',
                message: 'להסיר את ${p.displayName} מרשימת החברים?',
                confirmLabel: 'הסרה',
                confirmPalette: CandyPalette.red,
              );
              if (ok) await ref.read(socialRepositoryProvider).removeFriend(p.uid).catchError((_) {});
            },
          ),
        ],
      ),
    ),
  );
}

/// מאזן "ראש בראש" גדול: אני מול החבר/ה.
class _HeadToHead extends StatelessWidget {
  final int myWins;
  final int theirWins;
  final int games;
  final String theirName;

  const _HeadToHead({required this.myWins, required this.theirWins, required this.games, required this.theirName});

  @override
  Widget build(BuildContext context) {
    final leading = myWins == theirWins ? null : myWins > theirWins;
    Widget side(String name, int wins, bool highlight) => Expanded(
          child: Column(
            children: [
              Text(
                '$wins',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: highlight ? const Color(0xFF33C24D) : const Color(0xFF4A3F6B),
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF6B5E8F)),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'ראש בראש',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF7B3FF2)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              side('אני', myWins, leading == true),
              const Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFB9AEDB))),
              side(theirName, theirWins, leading == false),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            games == 0
                ? 'עוד לא שיחקתם יחד - זה הזמן להזמין!'
                : leading == null
                    ? 'שוויון אחרי $games משחקים'
                    : leading
                        ? 'את/ה מוביל/ה אחרי $games משחקים 💪'
                        : '$theirName מוביל/ה - הגיע הזמן לנקמה!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B5E8F)),
          ),
        ],
      ),
    );
  }
}

/// שורת השוואה "אני מול החבר/ה" עם פס מפוצל: החלק הירוק שלי, הסגול שלו/ה.
class _VsRow extends StatelessWidget {
  final String label;
  final IconData icon;

  /// null = אין נתון מקומי עבורי (מוצג רק הערך של החבר/ה).
  final int? mine;
  final int theirs;

  const _VsRow({required this.label, required this.icon, required this.mine, required this.theirs});

  @override
  Widget build(BuildContext context) {
    final m = mine;
    const green = Color(0xFF2FB34A);
    const purple = Color(0xFF8B5CF6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  m == null ? '' : '$m',
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: green),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 15, color: const Color(0xFF9D8FC4)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF4A3F6B)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$theirs',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: purple),
                ),
              ),
            ],
          ),
          if (m != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 9,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: (m + theirs) == 0 ? 0.5 : m / (m + theirs)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, share, _) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: (share * 1000).round().clamp(1, 999),
                        child: const ColoredBox(color: green),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: ((1 - share) * 1000).round().clamp(1, 999),
                        child: const ColoredBox(color: purple),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingFriendRequestsProvider);
    final outgoing = ref.watch(outgoingFriendRequestsProvider).valueOrNull ?? const [];
    final repo = ref.read(socialRepositoryProvider);

    return incoming.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorState(message: SocialActions.friendlyError(e)),
      data: (requests) {
        if (requests.isEmpty && outgoing.isEmpty) {
          return const _EmptyState(
            title: 'אין בקשות כרגע',
            message: 'כשמישהו ישלח לכם בקשת חברות - היא תופיע כאן (ותקבלו התראה).',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (requests.isNotEmpty) const _SectionTitle('בקשות שקיבלתי'),
            for (final r in requests)
              _RequestTile(
                avatarId: r.fromAvatarId,
                photoUrl: r.fromPhotoUrl,
                name: r.fromName,
                subtitle: r.createdAt == null ? 'עכשיו' : relativeTimeHe(r.createdAt!),
                actions: [
                  CandyIconButton(
                    icon: Icons.check_rounded,
                    palette: CandyPalette.green,
                    tooltip: 'אישור',
                    onPressed: () async {
                      try {
                        await repo.acceptFriendRequest(r);
                        if (context.mounted) {
                          GameToast.show(context, message: 'את/ה ו${r.fromName} עכשיו חברים! 🎉', icon: Icons.celebration_rounded);
                        }
                      } catch (e) {
                        if (context.mounted) GameToast.show(context, message: SocialActions.friendlyError(e), color: AppColors.error);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  CandyIconButton(
                    icon: Icons.close_rounded,
                    palette: CandyPalette.white,
                    tooltip: 'דחייה',
                    onPressed: () => repo.declineFriendRequest(r).catchError((_) {}),
                  ),
                ],
              ).animate().fadeIn(duration: 250.ms).scaleXY(begin: 0.96, end: 1),
            if (outgoing.isNotEmpty) const _SectionTitle('בקשות ששלחתי'),
            for (final r in outgoing)
              _RequestTile(
                avatarId: 'detective',
                name: r.toName.isEmpty ? 'שחקן/ית' : r.toName,
                subtitle: 'ממתין/ה לאישור',
                actions: [
                  TextButton(
                    onPressed: () => repo.cancelFriendRequest(r.toUid).catchError((_) {}),
                    child: const Text('ביטול', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final String avatarId;
  final String? photoUrl;
  final String name;
  final String subtitle;
  final List<Widget> actions;

  const _RequestTile({
    required this.avatarId,
    this.photoUrl,
    required this.name,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          AvatarWidget(avatarId: avatarId, photoUrl: photoUrl, size: 48, ring: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A80A8))),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// טאב הדירוג
// -----------------------------------------------------------------------------

class _LeaderboardTab extends ConsumerStatefulWidget {
  const _LeaderboardTab({super.key});

  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> {
  bool _byWins = false;
  PublicProfile? _me;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final repo = ref.read(socialRepositoryProvider);
    try {
      final uid = await repo.ensureSignedIn();
      final list = await repo.fetchProfiles([uid]);
      if (mounted && list.isNotEmpty) setState(() => _me = list.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final auth = ref.watch(authStateProvider).valueOrNull;
    final uid = ref.watch(socialUidProvider).valueOrNull ?? 'me';

    return friendsAsync.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorState(message: SocialActions.friendlyError(e)),
      data: (friends) {
        final me = PublicProfile(
          uid: uid,
          displayName: profile?.displayName ?? 'אני',
          avatarId: profile?.avatarId ?? 'detective',
          photoUrl: auth?.photoUrl,
          totalStars: profile?.totalStars ?? 0,
          highestLevel: profile?.highestUnlockedLevel ?? 1,
          mpGames: _me?.mpGames ?? 0,
          mpWins: _me?.mpWins ?? 0,
          status: PresenceStatus.online,
          lastActive: DateTime.now(),
        );
        int value(PublicProfile p) => _byWins ? p.mpWins : p.totalStars;
        final all = [me, ...friends.map((f) => f.profile)]..sort((a, b) => value(b).compareTo(value(a)));
        final myRank = all.indexWhere((p) => p.uid == me.uid) + 1;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToggleChip(label: '⭐ כוכבים', selected: !_byWins, onTap: () => setState(() => _byWins = false)),
                const SizedBox(width: 8),
                _ToggleChip(label: '🏆 ניצחונות', selected: _byWins, onTap: () => setState(() => _byWins = true)),
                const SizedBox(width: 8),
                // הדירוג היומי (אותו לוח לכולם) מוצג במסך האתגר היומי.
                _ToggleChip(label: '📅 אתגר היום', selected: false, onTap: () => context.push('/daily')),
              ],
            ),
            const SizedBox(height: 14),
            if (friends.isEmpty)
              const _EmptyState(
                title: 'הדירוג מחכה לחברים',
                message: 'הוסיפו חברים כדי לראות מי מוביל - בכוכבים ובניצחונות.',
              )
            else ...[
              _Podium(top: all.take(3).toList(), value: value, meUid: me.uid),
              const SizedBox(height: 10),
              Text(
                myRank == 1 ? 'את/ה במקום הראשון! 👑' : 'את/ה במקום $myRank מתוך ${all.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              for (int i = 3; i < all.length; i++)
                _RankRow(rank: i + 1, profile: all[i], value: value(all[i]), isMe: all[i].uid == me.uid, byWins: _byWins),
            ],
          ],
        );
      },
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900, color: selected ? const Color(0xFF5B2EC9) : Colors.white),
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<PublicProfile> top;
  final int Function(PublicProfile) value;
  final String meUid;

  const _Podium({required this.top, required this.value, required this.meUid});

  @override
  Widget build(BuildContext context) {
    // סדר ויזואלי: מקום 2, מקום 1 (במרכז וגבוה), מקום 3.
    final order = <int>[if (top.length > 1) 1, 0, if (top.length > 2) 2];
    const heights = [118.0, 88.0, 70.0];
    const medals = [Color(0xFFFFC93C), Color(0xFFCFD8DC), Color(0xFFFFAB76)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final i in order)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i == 0) const Text('👑', style: TextStyle(fontSize: 26)),
                PresenceAvatar.of(top[i], size: i == 0 ? 70 : 56),
                const SizedBox(height: 4),
                Text(
                  top[i].uid == meUid ? 'אני' : top[i].displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Container(
                  height: heights[i],
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [medals[i], Color.lerp(medals[i], Colors.black, 0.25)!],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Text('${i + 1}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text('${value(top[i])}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                )
                    .animate()
                    .scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, duration: 500.ms, delay: (120 * i).ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final PublicProfile profile;
  final int value;
  final bool isMe;
  final bool byWins;

  const _RankRow({required this.rank, required this.profile, required this.value, required this.isMe, required this.byWins});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFFF4C2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isMe ? Border.all(color: AppColors.star, width: 2) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF7B6CA8))),
          ),
          PresenceAvatar.of(profile, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${profile.displayName} (את/ה)' : profile.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
          ),
          Icon(byWins ? Icons.emoji_events_rounded : Icons.star_rounded, color: AppColors.star, size: 20),
          const SizedBox(width: 3),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// הוספת חבר
// -----------------------------------------------------------------------------

Future<void> showAddFriendDialog(BuildContext context) {
  return showGameDialog<void>(
    context: context,
    builder: (dialogContext) => const _AddFriendDialog(),
  );
}

class _AddFriendDialog extends ConsumerStatefulWidget {
  const _AddFriendDialog();

  @override
  ConsumerState<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<_AddFriendDialog> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;
  PublicProfile? _found;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    try {
      final result = await ref.read(socialRepositoryProvider).findByFriendCode(_controller.text);
      if (!mounted) return;
      setState(() {
        _found = result;
        _error = result == null ? 'לא נמצא שחקן עם הקוד הזה. בדקו שהקוד נכון.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = SocialActions.friendlyError(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentPlayersProvider);
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final friendIds = friends.map((f) => f.uid).toSet();
    final myUid = ref.watch(socialUidProvider).valueOrNull;
    final suggestions = recent.where((p) => !friendIds.contains(p.uid) && p.uid != myUid).take(6).toList();

    return GameDialog(
      title: 'הוספת חבר',
      ribbon: CandyPalette.purple,
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'הקלידו את קוד החבר (6 תווים) שחבר/ה שלח/ה לכם:',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5E557A)),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 6),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                filled: true,
                fillColor: const Color(0xFFF6F2FF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 10),
          CandyButton(
            label: 'חיפוש',
            icon: Icons.search_rounded,
            palette: CandyPalette.blue,
            height: 50,
            fontSize: 17,
            loading: _searching,
            onPressed: _search,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ],
          if (_found != null) ...[
            const SizedBox(height: 12),
            _FoundCard(profile: _found!, isFriend: friendIds.contains(_found!.uid)),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('שיחקתם יחד לאחרונה', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4A2F8F))),
            const SizedBox(height: 8),
            for (final p in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    AvatarWidget(avatarId: p.avatarId, size: 36, ring: false),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w800))),
                    TextButton.icon(
                      onPressed: () => SocialActions.sendFriendRequest(context, ref, uid: p.uid, name: p.displayName),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('הוספה'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FoundCard extends ConsumerWidget {
  final PublicProfile profile;
  final bool isFriend;
  const _FoundCard({required this.profile, required this.isFriend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7CEB6E), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PresenceAvatar.of(profile, size: 50),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    Text('⭐ ${profile.totalStars} · שלב ${profile.highestLevel}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CandyButton(
            label: isFriend ? 'כבר חברים ✓' : 'שליחת בקשת חברות',
            palette: CandyPalette.green,
            height: 48,
            fontSize: 16,
            onPressed: isFriend
                ? null
                : () async {
                    await SocialActions.sendFriendRequest(context, ref, uid: profile.uid, name: profile.displayName);
                    if (context.mounted) Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    ).animate().fadeIn().scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack);
  }
}

// -----------------------------------------------------------------------------
// מצבים כלליים
// -----------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        children: [
          const MascotWidget(mood: MascotMood.happy, size: 96),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const MascotWidget(mood: MascotMood.sad, size: 90),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _ErrorState(message: 'חברים ומשחק משותף דורשים חיבור לאינטרנט.'),
    );
  }
}
