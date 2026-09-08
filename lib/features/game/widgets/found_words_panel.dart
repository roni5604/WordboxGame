import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';

class FoundWordsPanel extends StatelessWidget {
  final List<String> words; // כבר בצורת תצוגה (עם אותיות סופיות)

  const FoundWordsPanel({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: Text('גררו בין אותיות כדי למצוא מילה ראשונה!',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: words.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final word = words[words.length - 1 - index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              word,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.3, end: 0);
        },
      ),
    );
  }
}
