import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SafetyPage extends StatelessWidget {
  final String userId;
  final String userName;

  const SafetyPage({super.key, required this.userId, required this.userName});

  Future<void> blockUser(BuildContext context) async {
    final me = FirebaseAuth.instance.currentUser;

    if (me == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .collection('blockedUsers')
        .doc(userId)
        .set({'userId': userId, 'blockedAt': FieldValue.serverTimestamp()});

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User blocked.')));

      Navigator.pop(context);
    }
  }

  Future<void> reportUser(BuildContext context, String reason) async {
    final me = FirebaseAuth.instance.currentUser;

    if (me == null) return;

    await FirebaseFirestore.instance.collection('reports').add({
      'reportedUserId': userId,
      'reportedUserName': userName,
      'reportedBy': me.uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );

      Navigator.pop(context);
    }
  }

  void showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final reasons = [
          'Fake profile',
          'Harassment',
          'Inappropriate content',
          'Spam',
          'Other',
        ];

        return AlertDialog(
          title: const Text('Report user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) {
              return ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(context);
                  reportUser(context, reason);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.security, size: 70, color: Colors.pink),
            const SizedBox(height: 15),
            Text(
              userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.block, color: Colors.red),
                label: const Text('BLOCK USER'),
                onPressed: () {
                  blockUser(context);
                },
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag, color: Colors.orange),
                label: const Text('REPORT USER'),
                onPressed: () {
                  showReportDialog(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
