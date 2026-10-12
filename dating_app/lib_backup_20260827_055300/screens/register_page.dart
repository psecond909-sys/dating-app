import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final dob = TextEditingController();
  final bio = TextEditingController();

  String? gender;
  String? interestedIn;
  bool ageConfirmed = false;
  bool loading = false;
  bool obscure = true;

  int age(DateTime birth) {
    final now = DateTime.now();
    var value = now.year - birth.year;

    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      value--;
    }

    return value;
  }

  Future<void> chooseDob() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selected != null) {
      dob.text =
          '${selected.day}/${selected.month}/${selected.year}';
      setState(() {});
    }
  }

  Future<void> register() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty ||
        dob.text.isEmpty ||
        gender == null ||
        interestedIn == null) {
      message('Please complete all fields.');
      return;
    }

    if (!ageConfirmed) {
      message('You must confirm that you are 18 or older.');
      return;
    }

    final parts = dob.text.split('/');

    DateTime birth;

    try {
      birth = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      message('Invalid date of birth.');
      return;
    }

    if (age(birth) < 18) {
      message('LoveMatch is only for users 18+.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final user = credential.user!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': name.text.trim(),
        'email': email.text.trim(),
        'dateOfBirth': dob.text,
        'gender': gender,
        'interestedIn': interestedIn,
        'bio': bio.text.trim(),
        'photoUrl': '',
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      String text = 'Registration failed.';

      if (e.code == 'email-already-in-use') {
        text = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        text = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        text = 'Please enter a valid email.';
      }

      message(text);
    } catch (e) {
      message('Registration failed.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    dob.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: dob,
              readOnly: true,
              onTap: chooseDob,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Male',
                  child: Text('Male'),
                ),
                DropdownMenuItem(
                  value: 'Female',
                  child: Text('Female'),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other'),
                ),
              ],
              onChanged: (v) => setState(() => gender = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: interestedIn,
              decoration: const InputDecoration(
                labelText: 'Interested In',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Men',
                  child: Text('Men'),
                ),
                DropdownMenuItem(
                  value: 'Women',
                  child: Text('Women'),
                ),
                DropdownMenuItem(
                  value: 'Everyone',
                  child: Text('Everyone'),
                ),
              ],
              onChanged: (v) => setState(() => interestedIn = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: bio,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people something about you',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => obscure = !obscure);
                  },
                  icon: Icon(
                    obscure
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: ageConfirmed,
              onChanged: (v) {
                setState(() => ageConfirmed = v ?? false);
              },
              title: const Text('I confirm I am 18 or older.'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : register,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Create Account',
                        style: TextStyle(fontSize: 17),
                      ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                );
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
