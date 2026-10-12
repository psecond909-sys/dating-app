import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_page.dart';
import 'matches_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DiscoverPage(),
      const MatchesPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Matches'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> users = [];
  int index = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    final result = snapshot.docs
        .where((doc) => doc.id != FirebaseAuth.instance.currentUser?.uid)
        .toList();

    if (mounted) {
      setState(() {
        users = result;
        index = 0;
        loading = false;
      });
    }
  }

  Future<void> likeUser(String otherUid) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('likes')
        .doc(otherUid)
        .set({'createdAt': FieldValue.serverTimestamp()});

    final reciprocal = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .collection('likes')
        .doc(uid)
        .get();

    if (reciprocal.exists) {
      final ids = [uid, otherUid]..sort();
      await FirebaseFirestore.instance
          .collection('matches')
          .doc('${ids[0]}_${ids[1]}')
          .set({
            'users': [uid, otherUid],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (index >= users.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Discover')),
        body: Center(
          child: ElevatedButton(
            onPressed: loadUsers,
            child: const Text('Refresh'),
          ),
        ),
      );
    }

    final data = users[index].data();
    final uid = users[index].id;

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 70,
                      child: Icon(Icons.person, size: 80),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      data['name']?.toString() ?? 'User',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${data['gender'] ?? ''} • ${data['interestedIn'] ?? ''}',
                    ),
                    const SizedBox(height: 15),
                    Text(
                      data['bio']?.toString() ?? 'No bio',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'no',
                onPressed: () {
                  setState(() => index++);
                },
                child: const Icon(Icons.close),
              ),
              FloatingActionButton(
                heroTag: 'yes',
                backgroundColor: Colors.pink,
                onPressed: () async {
                  await likeUser(uid);
                  if (mounted) setState(() => index++);
                },
                child: const Icon(Icons.favorite, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 55, child: Icon(Icons.person, size: 60)),
            const SizedBox(height: 20),
            Text(user?.email ?? ''),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => logout(context),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
