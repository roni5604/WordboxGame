import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../game/widgets/mascot_widget.dart';

/// כל האוואטארים הזמינים לבחירה בפרופיל, עם תמונת תצוגה מקדימה (thumbnail)
/// ותווית בעברית. הוספת אוואטאר חדש = הוספת ערך אחד לרשימה הזו.
class AvatarOption {
  final String id;
  final String label;
  final String assetPath;

  const AvatarOption({required this.id, required this.label, required this.assetPath});
}

const List<AvatarOption> kAvatarOptions = [
  AvatarOption(
    id: 'detective',
    label: 'הבלש הפוינטר',
    assetPath: 'assets/avatar/detective_default.png',
  ),
  AvatarOption(
    id: 'mascot',
    label: 'קסמלה',
    assetPath: 'assets/mascot/mascot_happy.png',
  ),
];

AvatarOption avatarOptionFor(String id) =>
    kAvatarOptions.firstWhere((o) => o.id == id, orElse: () => kAvatarOptions.first);

/// מציג את האוואטאר הנבחר של השחקן כעיגול עם מסגרת וצל - משמש בפרופיל,
/// בתפריט הראשי, ובכל מקום אחר שרוצים "לחתום" עם זהות השחקן.
class AvatarWidget extends StatelessWidget {
  final String avatarId;
  final double size;
  final bool ring;

  /// תמונת הפרופיל האמיתית מהספק (Google/Apple/Facebook), אם קיימת - נלקחת
  /// חיה מ-authStateProvider ע"י מי שמשתמש בווידג'ט. כשקיימת היא מוצגת
  /// במקום האוואטאר המצויר; אם הטעינה נכשלת (או שאין תמונה) חוזרים לאוואטאר.
  final String? photoUrl;

  const AvatarWidget({
    super.key,
    required this.avatarId,
    this.size = 88,
    this.ring = true,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final option = avatarOptionFor(avatarId);
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? size * 0.06 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: ring ? Border.all(color: AppColors.star, width: size * 0.03) : null,
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Image.asset(option.assetPath, fit: BoxFit.cover),
              )
            : Image.asset(option.assetPath, fit: BoxFit.cover),
      ),
    );
  }
}

/// אותו רעיון, אך "חי" - לשימוש במקומות שרוצים גם את אנימציית הריחוף של
/// הקמעון (כשהאוואטאר הנבחר הוא 'mascot'), או תמונה סטטית עבור הבלש.
class AnimatedAvatar extends StatelessWidget {
  final String avatarId;
  final double size;
  final MascotMood mood;

  /// תמונת הפרופיל האמיתית מהספק (Google/Apple/Facebook), אם קיימת - ראו
  /// תיעוד ב-[AvatarWidget.photoUrl].
  final String? photoUrl;

  const AnimatedAvatar({
    super.key,
    required this.avatarId,
    this.size = 110,
    this.mood = MascotMood.happy,
    this.photoUrl,
  });

  Widget _fallback() {
    if (avatarId == 'mascot') {
      return MascotWidget(mood: mood, size: size);
    }
    return Image.asset(
      mood == MascotMood.excited
          ? 'assets/avatar/detective_celebrate.png'
          : 'assets/avatar/detective_default.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    if (hasPhoto) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }
}
