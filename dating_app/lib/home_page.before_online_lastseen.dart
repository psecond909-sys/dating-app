import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'matches_page.dart';
import 'likes_received_page.dart';
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
      const LikesReceivedPage(),
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
            label: 'Likes',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
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
                        photoUrl: data['photoUrl']?.toString(),
                        gender: data['gender']?.toString(),
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
  final String? photoUrl;
  final String? gender;
  final VoidCallback? onPassed;

  const ProfileCard({
    super.key,
    required this.userId,
    required this.name,
    required this.age,
    required this.city,
    this.photoUrl,
    this.gender,
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
      final myLikeRef = firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likes')
          .doc(userId);

      final otherLikeRef = firestore
          .collection('users')
          .doc(userId)
          .collection('likes')
          .doc(currentUser.uid);

      // Save my like.
      await myLikeRef.set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify the other user.
      await firestore
          .collection('users')
          .doc(userId)
          .collection('receivedLikes')
          .doc(currentUser.uid)
          .set({
        'userId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Check whether they already liked me.
      final otherLike = await otherLikeRef.get();

      if (otherLike.exists) {
        // MUTUAL LIKE = MATCH ❤️
        final ids = [currentUser.uid, userId]..sort();
        final matchId = ids.join('_');

        await firestore.collection('matches').doc(matchId).set({
          'users': ids,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save match for both users.
        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('matches')
            .doc(userId)
            .set({
          'userId': userId,
          'matchId': matchId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await firestore
            .collection('users')
            .doc(userId)
            .collection('matches')
            .doc(currentUser.uid)
            .set({
          'userId': currentUser.uid,
          'matchId': matchId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("It's a match with $name! ❤️"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You liked $name ❤️ You can message them up to 5 times today.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      onPassed?.call();
    } catch (e) {
      if (!context.mounted) return;

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
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? Image.network(
                    photoUrl!,
                    width: double.infinity,
                    height: 330,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.person,
                          size: 140,
                          color: Colors.white,
                        ),
                      );
                    },
                  )
                : const Center(
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
                if (gender != null && gender!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: Colors.pink,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        gender!,
                        style: const TextStyle(
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool uploadingPhoto = false;

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomePage(),
      ),
      (route) => false,
    );
  }

  Future<void> changeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (picked == null) return;

      setState(() {
        uploadingPhoto = true;
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(File(picked.path));

      final photoUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoUrl': photoUrl,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated ❤️'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update photo: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please log in again.'),
      );
    }

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.pink,
              ),
            );
          }

          final data = snapshot.data?.data() ?? {};

          final name = data['name']?.toString() ?? 'Your Name';
          final gender = data['gender']?.toString() ?? '';
          final photoUrl = data['photoUrl']?.toString();

          int? age;

          final dob = data['dateOfBirth'];

          if (dob is Timestamp) {
            final birthDate = dob.toDate();
            final now = DateTime.now();

            age = now.year - birthDate.year;

            if (now.month < birthDate.month ||
                (now.month == birthDate.month &&
                    now.day < birthDate.day)) {
              age--;
            }
          } else if (data['age'] is int) {
            age = data['age'] as int;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 75,
                      backgroundColor: const Color(0xFFFFE0E6),
                      backgroundImage:
                          photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 75,
                              color: Colors.pink,
                            )
                          : null,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed:
                            uploadingPhoto ? null : changeProfilePhoto,
                        icon: uploadingPhoto
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TextButton.icon(
                  onPressed:
                      uploadingPhoto ? null : changeProfilePhoto,
                  icon: const Icon(
                    Icons.photo_library,
                    color: Colors.pink,
                  ),
                  label: Text(
                    uploadingPhoto
                        ? 'Uploading...'
                        : 'Change Profile Picture',
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (age != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '$age years old',
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),
                ],

                if (gender.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    gender,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Text(
                  user.email ?? '',
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.pink,
                        size: 35,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        photoUrl != null && photoUrl.isNotEmpty
                            ? 'Profile photo uploaded ❤️'
                            : 'No profile photo uploaded',
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

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
          );
        },
      ),
    );
  }
}
