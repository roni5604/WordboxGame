import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/level_progress.dart';
import '../models/player_profile.dart';
import '../services/auth_session.dart';
import 'progress_repository.dart';

/// מימוש Firebase (Firestore) של [ProgressRepository] - מסנכרן את התקדמות
/// השחקן לענן, כך שהיא זמינה גם מהאתר וגם מהאפליקציה תחת אותו משתמש.
///
/// לא פעיל כברירת מחדל! מופעל רק לאחר:
/// 1. הרצת `flutterfire configure` (ראו docs/FIREBASE_SETUP.md).
/// 2. הפעלת AppConfig.useFirebaseBackend.
/// 3. Override לספק progressRepositoryProvider בקובץ
///    lib/providers/repository_providers.dart להחזיר מופע של המחלקה הזו.
///
/// שימו לב: ה-constructor דורש משתמש מחובר (גם אנונימי) - יש לוודא
/// ש-FirebaseAuth.instance.currentUser אינו null לפני שימוש (למשל ע"י
/// קריאה ל-FirebaseAuth.instance.signInAnonymously()).
///
/// [boundUid]: המשתמש/ת שההתקדמות הזו שייכת לו/לה. כשהחשבון מתחלף (התנתקות,
/// התחברות לחשבון קיים), נוצר מופע חדש לחשבון החדש, ושמירות מאוחרות של
/// המופע הישן *לא* נכתבות לחשבון החדש - אחרת שם, מטבעות והתקדמות של חשבון
/// אחד היו דורסים חשבון אחר.
class FirebaseProgressRepository implements ProgressRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String? boundUid;

  FirebaseProgressRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, this.boundUid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('players').doc(uid);
  }

  Future<String> _ensureUid() async {
    return AuthSession.ensureUid(_auth);
  }

  /// קריאה עם ניסיון חוזר אחד: מיד אחרי התחברות, השרת עלול עדיין לראות
  /// את המשתמש הקודם לרגע (permission-denied) או שהרשת עוד לא מוכנה.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getWithRetry(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'unavailable') rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return ref.get();
    }
  }

  @override
  Future<PlayerProfile> loadProfile() async {
    final uid = boundUid ?? await _ensureUid();
    final snapshot = await _getWithRetry(_profileDoc(uid));
    if (!snapshot.exists) {
      // מתנת פתיחה חד-פעמית לפרופיל ענן חדש (ראו PlayerProfile.starterHints).
      const fresh = PlayerProfile(hints: PlayerProfile.starterHints);
      await saveProfile(fresh);
      return fresh;
    }
    final data = snapshot.data()!;

    final levelsRaw = Map<String, dynamic>.from(data['levelProgress'] as Map? ?? {});
    final levelProgress = <int, LevelProgress>{
      for (final entry in levelsRaw.entries)
        int.parse(entry.key): LevelProgress(
          levelNumber: int.parse(entry.key),
          stars: (entry.value['stars'] as num?)?.toInt() ?? 0,
          bestScore: (entry.value['bestScore'] as num?)?.toInt() ?? 0,
          completed: entry.value['completed'] as bool? ?? false,
        ),
    };

    return PlayerProfile(
      levelProgress: levelProgress,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      highestUnlockedLevel: (data['highestUnlockedLevel'] as num?)?.toInt() ?? 1,
      soundOn: data['soundOn'] as bool? ?? true,
      hapticsOn: data['hapticsOn'] as bool? ?? true,
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      displayName: data['displayName'] as String? ?? 'שחקן/ית',
      avatarId: data['avatarId'] as String? ?? 'detective',
      hints: (data['hints'] as num?)?.toInt() ?? 0,
      hintStreakDay: (data['hintStreakDay'] as num?)?.toInt() ?? 0,
      lastHintClaimDate: data['lastHintClaimDate'] as String?,
      authIntroShown: data['authIntroShown'] as bool? ?? false,
      level1TutorialSeen: data['level1TutorialSeen'] as bool? ?? false,
      doubleCoinsLevelsRemaining:
          (data['doubleCoinsLevelsRemaining'] as num?)?.toInt() ?? 0,
      boardSkinId: data['boardSkinId'] as String? ?? 'classic',
      letterSkinId: data['letterSkinId'] as String? ?? 'classic',
      markerSkinId: data['markerSkinId'] as String? ?? 'classic',
      ownedBoardSkins: _stringList(data['ownedBoardSkins']),
      ownedLetterSkins: _stringList(data['ownedLetterSkins']),
      ownedMarkerSkins: _stringList(data['ownedMarkerSkins']),
      dailyChallengeDate: data['dailyChallengeDate'] as String?,
      dailyChallengeScore: (data['dailyChallengeScore'] as num?)?.toInt() ?? 0,
      dailyChallengeWords: (data['dailyChallengeWords'] as num?)?.toInt() ?? 0,
      dailyChallengeStreak: (data['dailyChallengeStreak'] as num?)?.toInt() ?? 0,
      dailyChallengeBestStreak: (data['dailyChallengeBestStreak'] as num?)?.toInt() ?? 0,
      dailyChallengeStartedDate: data['dailyChallengeStartedDate'] as String?,
      dropsSinceEpic: (data['dropsSinceEpic'] as num?)?.toInt() ?? 0,
      unlockedChapters: _intList(data['unlockedChapters']),
    );
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    final bound = boundUid;
    if (bound != null && _auth.currentUser?.uid != bound) {
      // החשבון כבר התחלף: זו שמירה מאוחרת של החשבון הקודם - לא כותבים.
      return;
    }
    final uid = bound ?? await _ensureUid();
    final levelsMap = {
      for (final entry in profile.levelProgress.entries)
        entry.key.toString(): {
          'stars': entry.value.stars,
          'bestScore': entry.value.bestScore,
          'completed': entry.value.completed,
        },
    };

    await _profileDoc(uid).set({
      'levelProgress': levelsMap,
      'coins': profile.coins,
      'highestUnlockedLevel': profile.highestUnlockedLevel,
      'soundOn': profile.soundOn,
      'hapticsOn': profile.hapticsOn,
      'onboardingCompleted': profile.onboardingCompleted,
      'displayName': profile.displayName,
      'avatarId': profile.avatarId,
      'hints': profile.hints,
      'hintStreakDay': profile.hintStreakDay,
      'lastHintClaimDate': profile.lastHintClaimDate,
      'authIntroShown': profile.authIntroShown,
      'level1TutorialSeen': profile.level1TutorialSeen,
      'doubleCoinsLevelsRemaining': profile.doubleCoinsLevelsRemaining,
      'boardSkinId': profile.boardSkinId,
      'letterSkinId': profile.letterSkinId,
      'markerSkinId': profile.markerSkinId,
      'ownedBoardSkins': profile.ownedBoardSkins,
      'ownedLetterSkins': profile.ownedLetterSkins,
      'ownedMarkerSkins': profile.ownedMarkerSkins,
      'dailyChallengeDate': profile.dailyChallengeDate,
      'dailyChallengeScore': profile.dailyChallengeScore,
      'dailyChallengeWords': profile.dailyChallengeWords,
      'dailyChallengeStreak': profile.dailyChallengeStreak,
      'dailyChallengeBestStreak': profile.dailyChallengeBestStreak,
      'dailyChallengeStartedDate': profile.dailyChallengeStartedDate,
      'dropsSinceEpic': profile.dropsSinceEpic,
      'unlockedChapters': profile.unlockedChapters,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

List<String> _stringList(Object? raw) {
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => e.toString()).toList();
  }
  return const ['classic'];
}

List<int> _intList(Object? raw) {
  if (raw is! List) return const [];
  return [for (final e in raw) if (e is num) e.toInt()];
}
