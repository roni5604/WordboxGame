import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/auth_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';

/// מסך התחברות/הרשמה: Google, Apple, Facebook, מייל+סיסמה, או המשך
/// כאורח/ת. נגיש דרך מסך הפרופיל. עובד תמיד (גם בלי Firebase מוגדר) -
/// אם השרת לא הופעל עדיין, לחיצה על ספק אמיתי מציגה הסבר ידידותי במקום
/// לקרוס, והמשך כאורח/ת עדיין זמין תמיד.
class AuthScreen extends ConsumerStatefulWidget {
  /// true כאשר זהו מסך ההתחברות הראשוני שמוצג בכניסה הראשונה לאפליקציה
  /// (לפני ההדרכה) - במצב הזה אין כפתור חזרה, וכל בחירה (כולל "אורח/ת")
  /// ממשיכה אוטומטית להדרכה/לתפריט הראשי במקום לסגור את המסך.
  final bool isInitial;

  const AuthScreen({super.key, this.isInitial = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _EmailMode { signIn, register }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  _EmailMode _emailMode = _EmailMode.signIn;
  bool _showEmailForm = false;
  String? _busyAction;

  bool get _appleAvailable => kIsWeb || Platform.isIOS || Platform.isMacOS;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// מסמן שהמסך הראשוני נצפה ונבחרה בו אפשרות, ומעביר להדרכה (אם עוד לא
  /// עברו אותה) או ישר לתפריט הראשי - זה קורה בדיוק פעם אחת בחיי המשתמש/ת.
  Future<void> _completeInitialAuth() async {
    await ref.read(playerProfileProvider.notifier).setAuthIntroShown();
    if (!mounted) return;
    final profile = ref.read(playerProfileProvider).valueOrNull;
    context.go(profile?.onboardingCompleted == true ? '/home' : '/onboarding');
  }

  Future<void> _run(String action, Future<AuthUser> Function() task) async {
    setState(() => _busyAction = action);
    try {
      final user = await task();
      if (!mounted) return;
      // אחרי כל התחברות מוצלחת לחשבון אמיתי (לא אורח/ת), מסנכרנים את השם
      // מהספק (Google/Apple/Facebook/מייל) לפרופיל - כך שהשם והתמונה
      // (הנלקחת חיה מ-authStateProvider) יתעדכנו בכל מקום במשחק.
      await ref.read(playerProfileProvider.notifier).syncFromAuthUser(user);
      if (!mounted) return;
      if (widget.isInitial) {
        await _completeInitialAuth();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('התחברתם בהצלחה! 🎉'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('שגיאה: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final repo = ref.read(authRepositoryProvider);
    final user = authAsync.valueOrNull;
    final isRealAccount = user != null && !user.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (!widget.isInitial)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                  ],
                )
              else
                const SizedBox(height: 12),
              const SizedBox(height: 4),
              Center(
                child: Image.asset('assets/avatar/detective_explain.png', height: 130)
                    .animate()
                    .fadeIn()
                    .scale(begin: const Offset(0.85, 0.85)),
              ),
              const SizedBox(height: 12),
              const Text(
                'התחברות ויצירת חשבון',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'התחברו כדי לשמור את ההתקדמות שלכם בענן ולשחק מכל מכשיר -\n'
                'או פשוט המשיכו כאורח/ת בלי שום התחייבות.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (isRealAccount) ...[
                _AccountCard(user: user, onSignOut: () => _run('signout', () async {
                      await repo.signOut();
                      return await repo.signInAsGuest();
                    })),
                const SizedBox(height: 20),
              ] else ...[
                _AuthButton(
                  label: 'המשך עם Google',
                  icon: Icons.g_mobiledata_rounded,
                  iconColor: const Color(0xFFEA4335),
                  background: Colors.white,
                  foreground: AppColors.textDark,
                  busy: _busyAction == 'google',
                  onTap: () => _run('google', repo.signInWithGoogle),
                ),
                const SizedBox(height: 12),
                if (_appleAvailable) ...[
                  _AuthButton(
                    label: 'המשך עם Apple',
                    icon: Icons.apple_rounded,
                    iconColor: Colors.white,
                    background: Colors.black,
                    foreground: Colors.white,
                    busy: _busyAction == 'apple',
                    onTap: () => _run('apple', repo.signInWithApple),
                  ),
                  const SizedBox(height: 12),
                ],
                _AuthButton(
                  label: 'המשך עם Facebook',
                  icon: Icons.facebook_rounded,
                  iconColor: Colors.white,
                  background: const Color(0xFF1877F2),
                  foreground: Colors.white,
                  busy: _busyAction == 'facebook',
                  onTap: () => _run('facebook', repo.signInWithFacebook),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('או', style: TextStyle(color: Colors.white70)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_showEmailForm)
                  _AuthButton(
                    label: 'התחברות עם מייל וסיסמה',
                    icon: Icons.email_rounded,
                    iconColor: AppColors.primary,
                    background: Colors.white,
                    foreground: AppColors.textDark,
                    busy: false,
                    onTap: () => setState(() => _showEmailForm = true),
                  )
                else
                  _EmailForm(
                    mode: _emailMode,
                    nameController: _nameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    busy: _busyAction == 'email',
                    onToggleMode: () => setState(() {
                      _emailMode = _emailMode == _EmailMode.signIn
                          ? _EmailMode.register
                          : _EmailMode.signIn;
                    }),
                    onSubmit: () {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text;
                      final name = _nameController.text.trim();
                      if (email.isEmpty || password.isEmpty) return;
                      _run('email', () {
                        if (_emailMode == _EmailMode.register) {
                          return repo.registerWithEmail(
                            email: email,
                            password: password,
                            displayName: name.isEmpty ? 'שחקן/ית' : name,
                          );
                        }
                        return repo.signInWithEmail(email: email, password: password);
                      });
                    },
                  ),
                const SizedBox(height: 28),
              ],
              Center(
                child: TextButton(
                  onPressed: _busyAction != null
                      ? null
                      : () {
                          if (widget.isInitial) {
                            _run('guest', repo.signInAsGuest);
                          } else {
                            context.pop();
                          }
                        },
                  child: Text(
                    isRealAccount ? 'חזרה' : 'המשך כאורח/ת בלי להתחבר',
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onSignOut;

  const _AccountCard({required this.user, required this.onSignOut});

  String get _providerLabel => switch (user.provider) {
        AuthProviderType.google => 'Google',
        AuthProviderType.apple => 'Apple',
        AuthProviderType.facebook => 'Facebook',
        AuthProviderType.email => 'מייל וסיסמה',
        AuthProviderType.guest => 'אורח/ת',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 32)
                : null,
          ),
          const SizedBox(height: 12),
          Text(user.displayName ?? user.email ?? 'משתמש/ת',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('מחובר/ת עם $_providerLabel',
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: onSignOut, child: const Text('התנתקות')),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color foreground;
  final bool busy;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.foreground,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
                )
              else ...[
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  final _EmailMode mode;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;

  const _EmailForm({
    required this.mode,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.onToggleMode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isRegister = mode == _EmailMode.register;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          if (isRegister) ...[
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'כינוי', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'אימייל', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'סיסמה', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onSubmit,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isRegister ? 'יצירת חשבון' : 'התחברות'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onToggleMode,
            child: Text(isRegister ? 'כבר יש לכם חשבון? התחברו' : 'משתמשים חדשים? הרשמה'),
          ),
        ],
      ),
    );
  }
}
