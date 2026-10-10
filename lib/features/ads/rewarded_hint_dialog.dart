import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';

/// שאלה לפני Rewarded באמצע שלב, כשנגמרו הרמזים. true אם בחרו לצפות.
Future<bool> showRewardedHintDialog(
  BuildContext context, {
  required int remainingToday,
}) async {
  final watch = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.star,
              size: 46,
            ),
            const SizedBox(height: 10),
            const Text(
              'רמז תמורת צפייה',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'נגמרו הרמזים. צפו בפרסומת קצרה וקבלו רמז אחד לשלב הזה.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'נשארו $remainingToday היום',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CandyButton(
                    label: 'לא עכשיו',
                    palette: CandyPalette.white,
                    height: 50,
                    fontSize: 16,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CandyButton(
                    label: 'צפייה',
                    icon: Icons.play_circle_fill_rounded,
                    palette: CandyPalette.green,
                    height: 50,
                    fontSize: 16,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return watch ?? false;
}
