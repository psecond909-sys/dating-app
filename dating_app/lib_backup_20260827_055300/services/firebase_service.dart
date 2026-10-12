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
    }, SetOptions(merge: true));
  }

  static Future<void> saveLocation(
    double latitude,
    double longitude,
  ) async {
    await db.collection('users').doc(uid).set({
      'latitude': latitude,
      'longitude': longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> likeUser(String otherUid) async {
    final myRef = db.collection('users').doc(uid);
    final otherRef = db.collection('users').doc(otherUid);

    final myLikeRef = myRef.collection('likes').doc(otherUid);

    await myLikeRef.set({
      'uid': otherUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final otherLike = await otherRef.collection('likes').doc(uid).get();

    if (otherLike.exists) {
      final matchId = [uid, otherUid]..sort();
      final id = '${matchId[0]}_${matchId[1]}';

      await db.collection('matches').doc(id).set({
        'users': [uid, otherUid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Future<void> passUser(String otherUid) async {
    await db
        .collection('users')
        .doc(uid)
        .collection('passes')
        .doc(otherUid)
        .set({
      'uid': otherUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> matches() {
    return db
        .collection('matches')
        .where('users', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  static Future<void> sendMessage(
    String otherUid,
    String text,
  ) async {
    final ids = [uid, otherUid]..sort();
    final matchId = '${ids[0]}_${ids[1]}';

    final chat = db
        .collection('matches')
        .doc(matchId)
        .collection('messages');

    await chat.add({
      'senderId': uid,
      'receiverId': otherUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await db.collection('matches').doc(matchId).set({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messages(
    String otherUid,
  ) {
    final ids = [uid, otherUid]..sort();
    final matchId = '${ids[0]}_${ids[1]}';

    return db
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  static Future<void> blockUser(String otherUid) async {
    await db
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(otherUid)
        .set({
      'uid': otherUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> reportUser(
    String otherUid,
    String reason,
  ) async {
    await db.collection('reports').add({
      'reportedBy': uid,
      'reportedUser': otherUid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
