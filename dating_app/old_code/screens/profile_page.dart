import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';
import 'welcome_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  final bio = TextEditingController();

  bool loading = true;
  String email = '';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final doc = await FirebaseService.db
        .collection('users')
        .doc(FirebaseService.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      name.text = data['name']?.toString() ?? '';
      bio.text = data['bio']?.toString() ?? '';
      email = data['email']?.toString() ?? '';
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> save() async {
    await FirebaseService.db.collection('users').doc(FirebaseService.uid).set({
      'name': name.text.trim(),
      'bio': bio.text.trim(),
    }, const SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> logout() async {
    await FirebaseService.updateOnline(false);
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const CircleAvatar(radius: 55, child: Icon(Icons.person, size: 60)),
          const SizedBox(height: 25),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          Text(email),
          const SizedBox(height: 15),
          TextField(
            controller: bio,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: save,
              child: const Text('Save Profile'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: logout, child: const Text('Logout')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }
}
