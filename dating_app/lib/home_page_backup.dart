import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'matches_page.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DiscoverPage(),
      const MatchesPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: Colors.pink.shade100,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
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
  final Set<String> passedUserIds = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> get usersStream {
    return FirebaseFirestore.instance
        .collection('users')
        .where('is18Plus', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discover',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.tune,
                      color: Colors.pink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: usersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pink,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Unable to load profiles.\n\n'
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final documents = snapshot.data?.docs ?? [];

                  final profiles = documents.where((doc) {
                    return doc.id != currentUser?.uid &&
                        !passedUserIds.contains(doc.id);
                  }).toList();

                  if (profiles.isEmpty) {
                    return const EmptyProfiles();
                  }

                  return ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final data = profiles[index].data();

                      return ProfileCard(
                        key: ValueKey(profiles[index].id),
                        userId: profiles[index].id,
                        name: data['name']?.toString() ?? 'User',
                        age: data['age'] is int
                            ? data['age'] as int
                            : int.tryParse(
                                  data['age']?.toString() ?? '',
                                ) ??
                                18,
                        city: data['city']?.toString() ?? 'Nearby',
                        onPassed: () {
                          setState(() {
                            passedUserIds.add(profiles[index].id);
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final String userId;
  final String name;
  final int age;
  final String city;
  final VoidCallback? onPassed;

  const ProfileCard({
    super.key,
    required this.userId,
    required this.name,
    required this.age,
    required this.city,
    this.onPassed,
  });

  Future<void> passUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('passes')
          .doc(userId)
          .set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Pass error: $e');
      rethrow;
    }
  }

  Future<void> likeUser(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likes')
          .doc(userId)
          .set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final reverseLike = await firestore
          .collection('users')
          .doc(userId)
          .collection('likes')
          .doc(currentUser.uid)
          .get();

      if (reverseLike.exists) {
        final ids = [currentUser.uid, userId]..sort();
        final matchId = ids.join('_');

        final matchData = {
          'users': [currentUser.uid, userId],
          'createdAt': FieldValue.serverTimestamp(),
        };

        await firestore.collection('matches').doc(matchId).set(matchData);

        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('matches')
            .doc(userId)
            .set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('matches')
            .doc(currentUser.uid)
            .set({
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 It\'s a Match! ❤️'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You liked $name ❤️'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Like error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 7,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Container(
            height: 330,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB6C8),
                  Color(0xFFFFE2E9),
                ],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name, $age',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.pink,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await passUser();

                          onPassed?.call();

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passed'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.redAccent,
                        ),
                        label: const Text('Pass'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => likeUser(context),
                        icon: const Icon(Icons.favorite),
                        label: const Text('Like'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyProfiles extends StatelessWidget {
  const EmptyProfiles({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.pink.shade50,
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              color: Colors.pink,
              size: 70,
            ),
            SizedBox(height: 15),
            Text(
              'No profiles yet',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Invite more people to join LoveMatch.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomePage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 65,
                backgroundColor: Color(0xFFFFE0E6),
                child: Icon(
                  Icons.person,
                  size: 70,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
