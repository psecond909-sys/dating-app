import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LoveMatchApp());
}

class LoveMatchApp extends StatelessWidget {
  const LoveMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LoveMatch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}


class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.favorite,
                  color: Colors.pink,
                  size: 90,
                ),

                const SizedBox(height: 20),

                const Text(
                  'LoveMatch',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Find meaningful connections',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 45),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  String? gender;
  String? interestedIn;
  bool ageConfirmed = false;

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
    }
  }

  int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month &&
            now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  Future<void> createAccount() async {
    if (name.text.trim().isEmpty ||
        dob.text.trim().isEmpty ||
        gender == null ||
        interestedIn == null ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      showMessage('Please complete all fields.');
      return;
    }

    if (!ageConfirmed) {
      showMessage('You must confirm that you are 18 or older.');
      return;
    }

    final parts = dob.text.split('/');

    if (parts.length != 3) {
      showMessage('Please enter date as DD/MM/YYYY');
      return;
    }

    DateTime birthDate;

    try {
      birthDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      showMessage('Invalid date of birth.');
      return;
    }

    if (calculateAge(birthDate) < 18) {
      showMessage('Sorry, LoveMatch is only for users 18+.');
      return;
    }

    try {
      showMessage('Creating your account...');

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final user = credential.user;

      if (user == null) {
        showMessage('Unable to create account.');
        return;
      }

      // Save profile information.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name.text.trim(),
          'dateOfBirth': dob.text.trim(),
          'gender': gender,
          'interestedIn': interestedIn,
          'email': email.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': false,
          'isTyping': false,
        });
      } catch (e) {
        debugPrint('Firestore save failed: $e');
      }

      // Registration automatically signs the user in.
      // Sign out because Login should be required.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // IMPORTANT: go to Login page after successful registration.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed.';

      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'network-request-failed') {
        message = 'Please check your internet connection.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('Registration failed: $e');
    }
  }

  void showMessage(String text) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 35, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.favorite,
                color: Colors.pink,
                size: 70,
              ),

              const SizedBox(height: 8),

              const Text(
                'LoveMatch',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Create your dating profile',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
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
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.person_search_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Man',
                    child: Text('Man'),
                  ),
                  DropdownMenuItem(
                    value: 'Woman',
                    child: Text('Woman'),
                  ),
                  DropdownMenuItem(
                    value: 'Non-binary',
                    child: Text('Non-binary'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => gender = value);
                },
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: interestedIn,
                decoration: const InputDecoration(
                  labelText: 'Interested In',
                  prefixIcon: Icon(Icons.favorite_border),
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
                onChanged: (value) {
                  setState(() => interestedIn = value);
                },
              ),

              const SizedBox(height: 14),

              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 8),

              CheckboxListTile(
                value: ageConfirmed,
                contentPadding: EdgeInsets.zero,
                controlAffinity:
                    ListTileControlAffinity.leading,
                title: const Text(
                  'I confirm that I am 18 years or older.',
                ),
                onChanged: (value) {
                  setState(() {
                    ageConfirmed = value ?? false;
                  });
                },
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: createAccount,
                  child: const Text(
                    'CREATE ACCOUNT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'LoveMatch is available only to adults 18+.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      showMessage('Please enter email and password.');
      return;
    }



    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final user = credential.user;

      if (user == null) {
        showMessage('Login failed.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'isOnline': true,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DiscoverPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email.';
      } else if (e.code == 'network-request-failed') {
        message = 'Please check your internet connection.';
      }

      showMessage(message);
    } catch (_) {
      showMessage('Login failed. Please try again.');
    } finally {

    }
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              const Icon(
                Icons.favorite,
                color: Colors.pink,
                size: 70,
              ),

              const SizedBox(height: 20),

              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Login to continue to LoveMatch',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 35),

              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: password,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 17),
                        ),
                ),
              ),

              const SizedBox(height: 15),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(),
                    ),
                  );
                },
                child: const Text(
                  "Don't have an account? Register",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LoveMatch ❤️'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite,
                size: 90,
                color: Colors.pink,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to LoveMatch!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                user?.email ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              const Text(
                'Discover people and find your match ❤️',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
