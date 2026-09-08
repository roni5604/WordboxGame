import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';

const _bgLetters = ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'מ', 'ק', 'ש', 'ת'];

/// מסך פתיחה: טוען את המילון ואת פרופיל השחקן ברקע, ומציג לוגו אנימטיבי
/// חמוד + רקע דקורטיבי של אותיות עבריות מרחפות בזמן ההמתנה. בסיום מנתב
/// להדרכה (פעם ראשונה) או ישר לתפריט הראשי.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusText = 'טוענים אוצר מילים בעברית...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareAndNavigate());
  }

  Future<void> _prepareAndNavigate() async {
    final stopwatch = Stopwatch()..start();

    await ref.read(dictionaryLoadProvider.future);
    if (mounted) setState(() => _statusText = 'מכינים את הלוח שלך...');
    final profile = await ref.read(playerProfileProvider.notifier).ensureLoaded();

    // מבטיח מסך פתיחה נעים למינימום זמן, גם אם הטעינה הייתה מהירה מדי.
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1300) {
      await Future.delayed(Duration(milliseconds: 1300 - elapsed));
    }

    if (!mounted) return;
    if (profile.onboardingCompleted) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _FloatingLettersBackground()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('מ', style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900)),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.08, duration: 900.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 12),
                  const MascotWidget(mood: MascotMood.happy, size: 64)
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 20),
                  const Text(
                    'מצא ת׳מילה',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'משחקה של ליאן רודן',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  const SizedBox(height: 44),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusText),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// אותיות עבריות שקופות למחצה, מרחפות ברקע - נותנות תחושת "משחק מילים"
/// חגיגית כבר במסך הראשון שנראה.
class _FloatingLettersBackground extends StatelessWidget {
  const _FloatingLettersBackground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final random = math.Random(7); // seed קבוע כדי שהפריסה תהיה עקבית
        return Stack(
          children: List.generate(_bgLetters.length, (i) {
            final left = random.nextDouble() * constraints.maxWidth;
            final top = random.nextDouble() * constraints.maxHeight;
            final size = 24.0 + random.nextDouble() * 28;
            final delay = (i * 137) % 1200;
            return Positioned(
              left: left,
              top: top,
              child: Text(
                _bgLetters[i],
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: -8,
                    end: 8,
                    duration: (1800 + delay).ms,
                    curve: Curves.easeInOut,
                  ),
            );
          }),
        );
      },
    );
  }
}
