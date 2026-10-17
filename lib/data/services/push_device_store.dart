import 'package:cloud_firestore/cloud_firestore.dart';

/// רישום המכשירים של שחקן/ית ל-push: `players/{uid}/devices/{token}`.
///
/// מזהה המסמך הוא טוקן ה-FCM עצמו, כך שאותו מכשיר לא נרשם פעמיים. השרת
/// (functions/) קורא מכאן לאן לשלוח, ומוחק טוקנים ש-FCM דוחה.
class PushDeviceStore {
  PushDeviceStore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> devices(String uid) =>
      _firestore.collection('players').doc(uid).collection('devices');

  Future<void> register({required String uid, required String token, required String platform}) {
    return devices(uid).doc(token).set({
      'token': token,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove({required String uid, required String token}) => devices(uid).doc(token).delete();
}
