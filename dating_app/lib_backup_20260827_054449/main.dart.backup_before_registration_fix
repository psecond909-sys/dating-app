import 'package:flutter/material.dart';

void main() {
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
      home: const RegisterPage(),
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

  void createAccount() {
    if (name.text.trim().isEmpty ||
        dob.text.isEmpty ||
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
    final birthDate = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );

    if (calculateAge(birthDate) < 18) {
      showMessage('Sorry, LoveMatch is only for users 18+.');
      return;
    }

    showMessage('Registration details accepted! ❤️');
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
