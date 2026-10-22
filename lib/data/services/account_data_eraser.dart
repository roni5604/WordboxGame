import 'package:cloud_firestore/cloud_firestore.dart';

/// מוחק מ-Firestore את כל הנתונים ששייכים למשתמש/ת, כחלק ממחיקת חשבון.
///
/// הכול נעשה מהלקוח, במסגרת חוקי האבטחה הקיימים (firestore.rules):
///   players/{uid}                          - ההתקדמות הפרטית
///   publicProfiles/{uid}                   - הכרטיס הציבורי
///   publicProfiles/{uid}/friends/*         - רשימת החברים שלי
///   publicProfiles/{friend}/friends/{uid}  - אני ברשימות של חברים
///   friendRequests (from/to = uid)         - בקשות חברות
///   invites (from/to = uid)                - הזמנות למשחק
///   blocks/{uid}/users/*                   - רשימת החסומים שלי
///
/// חדרי משחק (rooms) הם זמניים ומכילים רק כינוי וניקוד של סבב, ולכן לא
/// נמחקים כאן.
class AccountDataEraser {
  AccountDataEraser(this._firestore);

  final FirebaseFirestore _firestore;

  static const _batchLimit = 400;

  Future<void> eraseUser(String uid) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];

    final profiles = _firestore.collection('publicProfiles');
    final friends = await profiles.doc(uid).collection('friends').get();
    for (final doc in friends.docs) {
      refs.add(doc.reference);
      refs.add(profiles.doc(doc.id).collection('friends').doc(uid));
    }

    for (final collection in ['friendRequests', 'invites']) {
      for (final field in ['from', 'to']) {
        final snap = await _firestore
            .collection(collection)
            .where(field, isEqualTo: uid)
            .get();
        refs.addAll(snap.docs.map((d) => d.reference));
      }
    }

    final blocked = await _firestore.collection('blocks').doc(uid).collection('users').get();
    refs.addAll(blocked.docs.map((d) => d.reference));

    refs
      ..add(profiles.doc(uid))
      ..add(_firestore.collection('players').doc(uid));

    for (var i = 0; i < refs.length; i += _batchLimit) {
      final batch = _firestore.batch();
      final end = (i + _batchLimit).clamp(0, refs.length);
      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
