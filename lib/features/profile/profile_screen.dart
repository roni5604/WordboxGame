import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('פרופיל'),
        backgroundColor: AppColors.primary,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('שגיאה: $e')),
        data: (profile) {
          final levelsCompleted =
              profile.levelProgress.values.where((p) => p.completed).length;
          final totalLevels = CampaignLevels.all.length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarWidget(
                      avatarId: profile.avatarId,
                      size: 110,
                      photoUrl: authUser?.photoUrl,
                    ),
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openEditSheet(context, ref, profile),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => _openEditSheet(context, ref, profile),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white70),
                  label: const Text('עריכת אוואטאר וכינוי', style: TextStyle(color: Colors.white70)),
                ),
              ),
              Center(child: _AccountChip(user: authUser)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.star_rounded,
                      color: AppColors.star,
                      label: 'כוכבים',
                      value: '${profile.totalStars}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.paid_rounded,
                      color: Colors.amber,
                      label: 'מטבעות',
                      value: '${profile.coins}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.lightbulb_rounded,
                      color: Colors.amberAccent.shade400,
                      label: 'רמזים',
                      value: '${profile.hints}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.deepOrangeAccent,
                      label: 'רצף יומי',
                      value: 'יום ${profile.hintStreakDay == 0 ? '-' : profile.hintStreakDay}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.flag_rounded,
                color: AppColors.success,
                label: 'שלבים שהושלמו',
                value: '$levelsCompleted מתוך $totalLevels',
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.storefront_rounded,
                color: AppColors.accent,
                label: 'לקנות עוד רמזים?',
                value: '',
                fullWidth: true,
                trailing: FilledButton(
                  onPressed: () => context.push('/store'),
                  child: const Text('לחנות'),
                ),
              ),
            ],
          );
        },
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
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
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
                              color: _selectedAvatarId == option.id
                                  ? AppColors.primary
                                  : Colors.transparent,
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'איך לקרוא לך?',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('שמירה'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool fullWidth;
  final Widget? trailing;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.fullWidth = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: trailing != null
            ? Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  trailing!,
                ],
              )
            : Column(
                crossAxisAlignment:
                    fullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
      ),
    );
  }
}

/// "צ'יפ" קטן שמראה אם השחקן/ית מחובר/ת כאורח/ת או עם חשבון אמיתי, ומוביל
/// למסך ההתחברות (/auth) בלחיצה - שם אפשר להתחבר עם Google/Apple/Facebook/
/// מייל, או פשוט לחזור אורח/ת כרגיל.
class _AccountChip extends StatelessWidget {
  final AuthUser? user;

  const _AccountChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final isGuest = user == null || user!.isAnonymous;
    return GestureDetector(
      onTap: () => context.push('/auth'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
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
