import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/pressable.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/player_profile.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import 'widgets/avatar_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref, PlayerProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    return GameScaffold(
      colors: AppColors.gradientForWorldIndex(0),
      header: GameHeader(
        title: 'הפרופיל שלי',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        trailing: CandyIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'הגדרות',
          onPressed: () => context.push('/settings'),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, st) => const Center(
          child: Text('לא הצלחנו לטעון את הנתונים. נסו שוב.', style: TextStyle(color: Colors.white)),
        ),
        data: (profile) {
          final levelsCompleted = profile.levelProgress.values.where((p) => p.completed).length;
          final totalLevels = CampaignLevels.all.length;
          final tiles = [
            _StatTile(
              icon: Icons.star_rounded,
              color: const Color(0xFFFFB700),
              label: 'כוכבים',
              value: profile.totalStars,
            ),
            _StatTile(icon: Icons.paid_rounded, color: const Color(0xFFF59E0B), label: 'מטבעות', value: profile.coins),
            _StatTile(
              icon: Icons.lightbulb_rounded,
              color: const Color(0xFF7B3FF2),
              label: 'רמזים',
              value: profile.hints,
            ),
            _StatTile(
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF5A36),
              label: 'ימים ברצף',
              value: profile.hintStreakDay,
            ),
          ];
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(18, 0, 18, context.safeBottom(min: 20, extra: 20)),
            children: [
              Center(
                child: Pressable(
                  onTap: () => _openEditSheet(context, ref, profile),
                  semanticLabel: 'עריכת אוואטאר וכינוי',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
                        ),
                        child: AvatarWidget(
                          avatarId: profile.avatarId,
                          size: 104,
                          photoUrl: authUser?.photoUrl,
                          ring: false,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(child: _AccountChip(user: authUser)),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  for (int i = 0; i < tiles.length; i++)
                    tiles[i]
                        .animate()
                        .fadeIn(delay: (80 + 60 * i).ms)
                        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressCard(
                completed: levelsCompleted,
                total: totalLevels,
              ).animate().fadeIn(delay: 360.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              CandyButton(
                label: 'לחנות - עוד רמזים ועיצובים',
                icon: Icons.storefront_rounded,
                palette: CandyPalette.gold,
                height: 56,
                fontSize: 17,
                onPressed: () => context.push('/store?from=profile'),
              ).animate().fadeIn(delay: 420.ms),
            ],
          );
        },
      ),
    );
  }
}

/// כרטיס סטטיסטיקה: אייקון צבעוני, מספר שרץ, ותווית.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;

  const _StatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '$v',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: Color(0xFF2D2250),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF8A80A8), fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// התקדמות במפה: פס התקדמות מונפש וכמה שלבים הושלמו.
class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  const _ProgressCard({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'התקדמות במפה',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2D2250)),
                ),
              ),
              Text(
                '$completed מתוך $total',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 14,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: Color(0xFFEDE9F6))),
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF7CEB6E), Color(0xFF33C24D)]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            completed == 0
                ? 'כל מסע מתחיל בשלב אחד - קדימה!'
                : '${(ratio * 100).round()}% מהמסע הושלם · עוד ${total - completed} שלבים',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF8A80A8)),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final PlayerProfile profile;

  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late String _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _selectedAvatarId = widget.profile.avatarId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(playerProfileProvider.notifier);
    final name = _nameController.text.trim();
    if (name.isNotEmpty && name != widget.profile.displayName) {
      await notifier.setDisplayName(name);
    }
    if (_selectedAvatarId != widget.profile.avatarId) {
      await notifier.setAvatarId(_selectedAvatarId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('עריכת פרופיל', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          const Text('בחרו אוואטאר', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in kAvatarOptions)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAvatarId = option.id),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedAvatarId == option.id ? AppColors.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: AvatarWidget(avatarId: option.id, size: 72, ring: false),
                        ),
                        const SizedBox(height: 6),
                        Text(option.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('כינוי', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 18,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'איך לקרוא לך?'),
          ),
          const SizedBox(height: 8),
          CandyButton(label: 'שמירה', icon: Icons.check_rounded, palette: CandyPalette.green, height: 54, onPressed: _save),
        ],
      ),
    );
  }
}

/// "צ'יפ" קטן שמראה אם השחקן/ית מחובר/ת כאורח/ת או עם חשבון אמיתי, ומוביל
/// למסך ההתחברות (/auth) בלחיצה - שם אפשר להתחבר עם Google/Apple/
/// מייל, או פשוט לחזור אורח/ת כרגיל.
class _AccountChip extends StatelessWidget {
  final AuthUser? user;

  const _AccountChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final isGuest = user == null || user!.isAnonymous;
    return Pressable(
      onTap: () => context.push('/auth'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGuest ? Icons.person_outline_rounded : Icons.verified_user_rounded,
              color: isGuest ? Colors.white70 : AppColors.success,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isGuest ? 'משחק/ת כאורח/ת - להתחברות' : 'מחובר/ת - ניהול חשבון',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
