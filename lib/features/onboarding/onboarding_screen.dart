import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/player_profile_provider.dart';
import 'widgets/mini_grid_demo.dart';

class _OnboardingPage {
  final String emoji;
  final String title;
  final String description;
  final WidgetBuilder? demoBuilder;

  const _OnboardingPage(this.emoji, this.title, this.description, {this.demoBuilder});
}

final List<_OnboardingPage> _pages = [
  _OnboardingPage(
    '🔤',
    'חברו אותיות שכנות',
    'גררו אצבע בין אותיות סמוכות - אופקי, אנכי או באלכסון - כדי להרכיב מילים.',
    demoBuilder: (context) => const AnimatedMiniGridDemo(
      letters: ['ל', 'ב', 'י', 'ז', 'ת', 'ק'],
      columns: 3,
      path: [1, 2, 4],
    ),
  ),
  const _OnboardingPage(
    '⭐',
    'צברו כוכבים בכל שלב',
    'כל מילה שווה נקודות. ככל שהמילה ארוכה יותר - כך תרוויחו יותר!\n'
        'סיימו כל שלב עם עד 3 כוכבים לפי הניקוד שצברתם.',
  ),
  const _OnboardingPage(
    '🌱',
    'הלוח גדל איתכם',
    'מתחילים בלוח קטן וקל (3×3), ומתקדמים בהדרגה ללוחות גדולים ומאתגרים\n'
        'יותר - עד 7×7 בעולם "פסגת המילים"!',
  ),
  const _OnboardingPage(
    '👥',
    'תחרו נגד חברים',
    'במצב רב-משתתפים (2-4 שחקנים) כולם פותרים את אותו לוח - מי שמוצא/ת\n'
        'הכי הרבה מילים או צובר/ת הכי הרבה נקודות עד תום הזמן מנצח/ת!',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  /// כאשר true, המסך נפתח מהתפריט הראשי כ"איך משחקים" - במקום להשלים
  /// onboarding וללכת ל-/home, כפתור הסיום פשוט סוגר את המסך (pop).
  final bool standalone;

  const OnboardingScreen({super.key, this.standalone = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    if (widget.standalone) {
      if (mounted) context.pop();
      return;
    }
    await ref.read(playerProfileProvider.notifier).setOnboardingCompleted();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientForWorldIndex(_index),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      widget.standalone ? 'סגירה' : 'דלג',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (page.demoBuilder != null)
                            page.demoBuilder!(context).animate(key: ValueKey('demo-$i')).fadeIn()
                          else
                            Text(page.emoji, style: const TextStyle(fontSize: 96))
                                .animate(key: ValueKey('emoji-$i'))
                                .scale(duration: 400.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 32),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ).animate(key: ValueKey('title-$i')).fadeIn().slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 16),
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ).animate(key: ValueKey('desc-$i')).fadeIn(delay: 100.ms),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: active ? 1 : 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(isLast
                        ? (widget.standalone ? 'הבנתי, סגירה' : 'בואו נתחיל!')
                        : 'הבא'),
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
