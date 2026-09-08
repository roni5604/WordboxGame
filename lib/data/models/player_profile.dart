import 'package:equatable/equatable.dart';

import 'level_progress.dart';

/// מצב ההתקדמות הכולל של השחקן - נשמר מקומית (Hive), ובעתיד גם מסונכרן
/// ל-Firestore (ראו lib/data/repositories/firebase_progress_repository.dart).
class PlayerProfile extends Equatable {
  final Map<int, LevelProgress> levelProgress;
  final int coins;
  final int highestUnlockedLevel;
  final bool soundOn;
  final bool hapticsOn;
  final bool onboardingCompleted;
  final String displayName;

  /// מזהה האוואטאר הנבחר להצגה בפרופיל ובמקומות נוספים במשחק.
  /// ערכים אפשריים: 'detective' (הבלש הפוינטר - ברירת המחדל) או 'mascot'
  /// (הקמעון הצבעוני). ראה lib/features/profile/widgets/avatar_widget.dart.
  final String avatarId;

  /// יתרת הרמזים הנוכחית של השחקן. כל שחקן חדש מתחיל עם 5 רמזי מתנה.
  final int hints;

  /// היום הנוכחי במחזור הבונוס היומי (1-7). 0 = טרם נתבע רמז יומי כלשהו.
  /// כל יום נכנס מקבל רמז/י מתנה כמספר היום (יום 1=רמז אחד, יום 2=שניים...
  /// עד יום 7=שבעה), ולאחר מכן המחזור מתחיל מחדש מיום 1.
  final int hintStreakDay;

  /// תאריך התביעה היומית האחרונה בפורמט yyyy-MM-dd, כדי לוודא שהבונוס
  /// היומי נתבע לכל היותר פעם ביום קלנדרי אחד.
  final String? lastHintClaimDate;

  /// האם מסך ההתחברות הראשוני (Google/Apple/Facebook/מייל/אורח) כבר
  /// הוצג ונבחרה בו אפשרות - נבדק בכניסה הראשונה לאפליקציה, לפני ההדרכה.
  /// לאחר מכן לא מוצג שוב אוטומטית (אפשר עדיין להתחבר דרך הפרופיל).
  final bool authIntroShown;

  const PlayerProfile({
    this.levelProgress = const {},
    this.coins = 0,
    this.highestUnlockedLevel = 1,
    this.soundOn = true,
    this.hapticsOn = true,
    this.onboardingCompleted = false,
    this.displayName = 'שחקן/ית',
    this.avatarId = 'detective',
    this.hints = 0,
    this.hintStreakDay = 0,
    this.lastHintClaimDate,
    this.authIntroShown = false,
  });

  int get totalStars => levelProgress.values.fold(0, (sum, p) => sum + p.stars);

  bool isLevelUnlocked(int levelNumber) => levelNumber <= highestUnlockedLevel;

  LevelProgress progressFor(int levelNumber) =>
      levelProgress[levelNumber] ?? LevelProgress(levelNumber: levelNumber);

  PlayerProfile copyWith({
    Map<int, LevelProgress>? levelProgress,
    int? coins,
    int? highestUnlockedLevel,
    bool? soundOn,
    bool? hapticsOn,
    bool? onboardingCompleted,
    String? displayName,
    String? avatarId,
    int? hints,
    int? hintStreakDay,
    String? lastHintClaimDate,
    bool? authIntroShown,
  }) {
    return PlayerProfile(
      levelProgress: levelProgress ?? this.levelProgress,
      coins: coins ?? this.coins,
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      soundOn: soundOn ?? this.soundOn,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      hints: hints ?? this.hints,
      hintStreakDay: hintStreakDay ?? this.hintStreakDay,
      lastHintClaimDate: lastHintClaimDate ?? this.lastHintClaimDate,
      authIntroShown: authIntroShown ?? this.authIntroShown,
    );
  }

  @override
  List<Object?> get props => [
        levelProgress,
        coins,
        highestUnlockedLevel,
        soundOn,
        hapticsOn,
        onboardingCompleted,
        displayName,
        avatarId,
        hints,
        hintStreakDay,
        lastHintClaimDate,
        authIntroShown,
      ];
}
