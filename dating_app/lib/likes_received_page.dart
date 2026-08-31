import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LikesReceivedPage extends StatelessWidget {
  const LikesReceivedPage({super.key});

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    return doc.data();
  }

  Future<void> likeBack(
    BuildContext context,
    String likerId,
    Map<String, dynamic> likerData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      // Save my like back.
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likes')
          .doc(likerId)
          .set({
        'userId': likerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create the match.
      final ids = [currentUser.uid, likerId]..sort();
      final matchId = ids.join('_');

      await firestore.collection('matches').doc(matchId).set({
        'users': [currentUser.uid, likerId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add match for current user.
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matches')
          .doc(likerId)
          .set({
        'userId': likerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add match for other user.
      await firestore
          .collection('users')
          .doc(likerId)
          .collection('matches')
          .doc(currentUser.uid)
          .set({
        'userId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Remove the received like.
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('receivedLikes')
          .doc(likerId)
          .delete();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 It\'s a Match! ❤️'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Like back error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text('Please login again'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Likes ❤️'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('receivedLikes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load likes.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final likes = snapshot.data?.docs ?? [];

          if (likes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 70,
                    color: Colors.pink,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'No new likes',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('When someone likes you, they will appear here.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: likes.length,
            itemBuilder: (context, index) {
              final like = likes[index].data();
              final likerId = like['userId'] as String? ?? '';

              return FutureBuilder<Map<String, dynamic>?>(
                future: getUser(likerId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: CircularProgressIndicator(),
                        ),
                        title: Text('Loading...'),
                      ),
                    );
                  }

                  final userData = userSnapshot.data ?? {};
                  final name = userData['name']?.toString() ?? 'Someone';
                  final age = userData['age']?.toString() ?? '';
                  final city = userData['city']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Color(0xFFFFE0E6),
                            child: Icon(
                              Icons.person,
                              color: Colors.pink,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  age.isEmpty ? name : '$name, $age',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (city.isNotEmpty)
                                  Text(
                                    city,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () => likeBack(
                                    context,
                                    likerId,
                                    userData,
                                  ),
                                  icon: const Icon(Icons.favorite),
                                  label: const Text('Like Back ❤️'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pink,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
