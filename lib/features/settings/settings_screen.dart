import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/share/share_service.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';

/// צבעי מסך ההגדרות - סגול-כחלחל רגוע.
const kSettingsGradient = [Color(0xFF8B7CF6), Color(0xFF6D6AF0), Color(0xFF4F7DF3)];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);
    final ads = ref.watch(adsGatewayProvider);
    final notifier = ref.read(playerProfileProvider.notifier);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isRealAccount = authUser != null && !authUser.isAnonymous;

    return GameScaffold(
      colors: kSettingsGradient,
      header: GameHeader(title: 'הגדרות', onBack: () => context.canPop() ? context.pop() : context.go('/home')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, st) => Center(
          child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (profile) {
          final sections = <Widget>[
            _Section(
              title: 'צלילים ורטט',
              children: [
                _ToggleRow(
                  icon: Icons.volume_up_rounded,
                  color: const Color(0xFFFF7A45),
                  label: 'צלילים',
                  value: profile.soundOn,
                  onChanged: notifier.setSoundOn,
                ),
                _ToggleRow(
                  icon: Icons.vibration_rounded,
                  color: const Color(0xFF7B3FF2),
                  label: 'רטט',
                  value: profile.hapticsOn,
                  onChanged: notifier.setHapticsOn,
                ),
              ],
            ),
            _Section(
              title: 'חשבון',
              children: [
                if (isRealAccount)
                  _ActionRow(
                    icon: Icons.logout_rounded,
                    color: const Color(0xFF3A7BFF),
                    label: 'התנתקות',
                    subtitle: 'מחובר/ת עם ${authUser.displayName ?? authUser.email ?? 'חשבון'}',
                    onTap: () => _confirmSignOut(context, ref),
                  )
                else
                  _ActionRow(
                    icon: Icons.cloud_done_rounded,
                    color: const Color(0xFF33C24D),
                    label: 'התחברות / הרשמה',
                    subtitle: 'שמירת ההתקדמות והחברים בכל מכשיר',
                    onTap: () => context.push('/auth'),
                  ),
                if (ads.isSupported && ads.privacyOptionsRequired)
                  _ActionRow(
                    icon: Icons.privacy_tip_rounded,
                    color: const Color(0xFF14B8A6),
                    label: 'פרטיות בפרסומות',
                    subtitle: 'שינוי ההסכמה לפרסומות מותאמות',
                    onTap: () => ref.read(adsGatewayProvider).showPrivacyOptions(),
                  ),
              ],
            ),
            _Section(
              title: 'עזרה',
              children: [
                _ActionRow(
                  icon: Icons.school_rounded,
                  color: const Color(0xFFFFB700),
                  label: 'איך משחקים',
                  onTap: () => context.push('/how-to-play'),
                ),
                _ActionRow(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFFF4F8B),
                  label: 'חוקי המשחק',
                  onTap: () => context.push('/rules'),
                ),
                _ActionRow(
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFE11D48),
                  label: 'המליצו לחברים',
                  subtitle: 'שתפו קישור למשחק',
                  onTap: () => ShareService.system(
                    context,
                    text: 'מצאתי משחק מילים בעברית ממכר - "מצא ת׳מילה" 🔤\nבואו נתחרה! ${AppLinks.webBase}',
                  ),
                ),
              ],
            ),
            _Section(
              title: 'איפוס',
              children: [
                _ActionRow(
                  icon: Icons.restart_alt_rounded,
                  color: const Color(0xFFF2463D),
                  label: 'איפוס התקדמות',
                  subtitle: 'מוחק את כל השלבים, הכוכבים והמטבעות',
                  onTap: () => _confirmReset(context, notifier),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/icon/app_icon.png', width: 52, height: 52),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'מצא ת׳מילה',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Text(
                    'משחקו של רוני מיכאלי · iPhone, Android ואתר',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ];
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(18, 4, 18, context.safeBottom(min: 20, extra: 20)),
            children: [
              for (int i = 0; i < sections.length; i++)
                sections[i]
                    .animate()
                    .fadeIn(delay: (60 * i).ms, duration: 260.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'להתנתק?',
      message: 'תישארו מחוברים כאורח/ת ותוכלו לשמור התקדמות מקומית, ותמיד אפשר להתחבר בחזרה מאותו חשבון.',
      confirmLabel: 'התנתקות',
      confirmPalette: CandyPalette.blue,
    );
    if (!ok) return;
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    await repo.signInAsGuest();
    if (context.mounted) context.go('/home');
  }

  Future<void> _confirmReset(BuildContext context, PlayerProfileNotifier notifier) async {
    final ok = await showConfirmDialog(
      context,
      title: 'לאפס הכול?',
      message: 'כל השלבים, הכוכבים והמטבעות יימחקו. אי אפשר לבטל את הפעולה הזו.',
      confirmLabel: 'איפוס',
      confirmPalette: CandyPalette.red,
    );
    if (!ok) return;
    await notifier.resetProgress();
    if (context.mounted) {
      GameToast.show(context, message: 'ההתקדמות אופסה', icon: Icons.restart_alt_rounded);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 6),
            child: Text(
              title,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFEDE9F6)),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 21),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.color, required this.label, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2D2250)),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF8A80A8)),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Color(0xFFB9AEDB)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      pressedScale: 0.98,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2D2250)),
              ),
            ),
            CandySwitch(value: value),
          ],
        ),
      ),
    );
  }
}

/// מתג בסגנון משחק: מסילה ירוקה/אפורה וכדור לבן שקופץ לצד השני.
class CandySwitch extends StatelessWidget {
  final bool value;
  const CandySwitch({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      width: 58,
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF33C24D) : const Color(0xFFD9D4E6),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: value ? const Color(0xFF1E8F37) : const Color(0xFFB4ACC9), offset: const Offset(0, 2)),
        ],
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        // ב-RTL "פעיל" = הכדור בצד שמאל (סוף השורה).
        alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Icon(
            value ? Icons.check_rounded : Icons.close_rounded,
            size: 16,
            color: value ? const Color(0xFF33C24D) : const Color(0xFFB4ACC9),
          ),
        ),
      ),
    );
  }
}
