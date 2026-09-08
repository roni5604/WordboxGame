import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/level_progress.dart';
import '../models/player_profile.dart';
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
class FirebaseProgressRepository implements ProgressRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseProgressRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('players').doc(uid);
  }

  Future<String> _ensureUid() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  @override
  Future<PlayerProfile> loadProfile() async {
    final uid = await _ensureUid();
    final snapshot = await _profileDoc(uid).get();
    if (!snapshot.exists) {
      return const PlayerProfile();
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
    );
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    final uid = await _ensureUid();
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
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
