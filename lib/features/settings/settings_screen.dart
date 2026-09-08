import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);
    final notifier = ref.read(playerProfileProvider.notifier);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isRealAccount = authUser != null && !authUser.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('הגדרות'),
        backgroundColor: AppColors.primary,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('שגיאה: $e')),
        data: (profile) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('צלילים'),
                      secondary: const Icon(Icons.volume_up_rounded),
                      value: profile.soundOn,
                      onChanged: notifier.setSoundOn,
                    ),
                    SwitchListTile(
                      title: const Text('רטט (Haptics)'),
                      secondary: const Icon(Icons.vibration_rounded),
                      value: profile.hapticsOn,
                      onChanged: notifier.setHapticsOn,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isRealAccount) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.primary),
                    title: const Text('התנתקות'),
                    subtitle: Text(
                      'מחובר/ת עם ${authUser.displayName ?? authUser.email ?? 'חשבון'}',
                    ),
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restart_alt_rounded, color: AppColors.error),
                  title: const Text('איפוס התקדמות'),
                  subtitle: const Text('מוחק את כל השלבים, הכוכבים והמטבעות'),
                  onTap: () => _confirmReset(context, notifier),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'מצא ת׳מילה - גרסת בטא\nמשחקה של ליאן רודן. מבוסס על Flutter, מיועד ל-iOS, Android ואתר מקוד אחד.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('להתנתק מהחשבון?'),
        content: const Text(
          'תישארו מחוברים כאורח/ת ותוכלו לשמור התקדמות מקומית, '
          'ותמיד אפשר להתחבר בחזרה מאותו חשבון או מחשבון אחר.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () async {
              dialogContext.pop();
              final repo = ref.read(authRepositoryProvider);
              await repo.signOut();
              await repo.signInAsGuest();
              if (context.mounted) context.go('/home');
            },
            child: const Text('התנתקות', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, PlayerProfileNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('לאפס את כל ההתקדמות?'),
        content: const Text('פעולה זו אינה הפיכה.'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('ביטול')),
          TextButton(
            onPressed: () {
              notifier.resetProgress();
              context.pop();
            },
            child: const Text('איפוס', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
