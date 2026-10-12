import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import 'chat_page.dart';

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches ❤️')),
      body: StreamBuilder(
        stream: FirebaseService.db
            .collection('matches')
            .where('users', arrayContains: FirebaseService.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No matches yet'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final ids = List<String>.from(data['users'] ?? []);

              final other = ids.firstWhere(
                (id) => id != FirebaseService.uid,
                orElse: () => '',
              );

              return FutureBuilder(
                future: FirebaseService.db.collection('users').doc(other).get(),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data?.data();

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user?['name']?.toString() ?? 'Matched User'),
                    subtitle: Text(
                      data['lastMessage']?.toString() ?? 'Start chatting',
                    ),
                    trailing: const Icon(Icons.chat),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            otherUid: other,
                            otherName: user?['name']?.toString() ?? 'User',
                          ),
                        ),
                      );
                    },
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
