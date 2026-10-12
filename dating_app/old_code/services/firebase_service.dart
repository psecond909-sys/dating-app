import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final auth = FirebaseAuth.instance;
  static final db = FirebaseFirestore.instance;

  static String get uid => auth.currentUser!.uid;

  static Future<void> updateOnline(bool online) async {
    await db.collection('users').doc(uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, const SetOptions(merge: true));
  }

  static Future<void> saveLocation(double latitude, double longitude) async {
    await db.collection('users').doc(uid).set({
      'latitude': latitude,
      'longitude': longitude,
    }, const SetOptions(merge: true));
  }

  static Future<void> likeUser(String otherUid) async {
    await db.collection('users').doc(uid).collection('likes').doc(otherUid).set(
      {'createdAt': FieldValue.serverTimestamp()},
    );

    final otherLike = await db
        .collection('users')
        .doc(otherUid)
        .collection('likes')
        .doc(uid)
        .get();

    if (otherLike.exists) {
      final ids = [uid, otherUid]..sort();
      final matchId = '${ids[0]}_${ids[1]}';

      await db.collection('matches').doc(matchId).set({
        'users': [uid, otherUid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, const SetOptions(merge: true));
    }
  }

  static Future<void> passUser(String otherUid) async {
    await db
        .collection('users')
        .doc(uid)
        .collection('passes')
        .doc(otherUid)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  static Future<void> sendMessage(String otherUid, String text) async {
    final ids = [uid, otherUid]..sort();
    final matchId = '${ids[0]}_${ids[1]}';

    await db.collection('matches').doc(matchId).collection('messages').add({
      'senderId': uid,
      'receiverId': otherUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await db.collection('matches').doc(matchId).set({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, const SetOptions(merge: true));
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messages(String otherUid) {
    final ids = [uid, otherUid]..sort();
    final matchId = '${ids[0]}_${ids[1]}';

    return db
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }
}
