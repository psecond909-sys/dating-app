import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches ❤️'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('matches')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load matches.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final matches = snapshot.data?.docs ?? [];

          if (matches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 70,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No matches yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Keep discovering people and start matching ❤️',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final match = matches[index].data();
              final userId = match['userId'] as String? ?? '';

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(
                        child: CircularProgressIndicator(),
                      ),
                      title: Text('Loading...'),
                    );
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text('Profile unavailable'),
                    );
                  }

                  final profile = userSnapshot.data!.data()!;
                  final name = profile['name'] as String? ?? 'Unknown';
                  final age = profile['age']?.toString() ?? '';
                  final photoUrl = profile['photoUrl'] as String? ?? '';
                  final isOnline = profile['isOnline'] == true;
                  final lastSeenValue = profile['lastSeen'];

                  DateTime? lastSeen;
                  if (lastSeenValue is Timestamp) {
                    lastSeen = lastSeenValue.toDate();
                  }

                  String statusText;

                  if (isOnline) {
                    statusText = 'Online now';
                  } else if (lastSeen != null) {
                    final difference = DateTime.now().difference(lastSeen);

                    if (difference.inMinutes < 1) {
                      statusText = 'Last seen just now';
                    } else if (difference.inMinutes < 60) {
                      statusText =
                          'Last seen ${difference.inMinutes} min ago';
                    } else if (difference.inHours < 24) {
                      statusText =
                          'Last seen ${difference.inHours} hr ago';
                    } else {
                      statusText = 'Last seen ${difference.inDays} days ago';
                    }
                  } else {
                    statusText = 'Offline';
                  }

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child:
                            photoUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        age.isNotEmpty ? '$name, $age' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              statusText,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.chat_bubble_outline,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              userId: userId,
                              userName: name,
                            ),
                          ),
                        );
                      },
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
