import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  DateTime? dateOfBirth;
  bool is18Plus = false;
  String? gender;
  bool loading = false;
  bool hidePassword = true;
  File? profileImage;

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int result = today.year - dob.year;

    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      result--;
    }

    return result;
  }

  int get age {
    if (dateOfBirth == null) {
      return 0;
    }

    return _calculateAge(dateOfBirth!);
  }

  Future<void> selectDateOfBirth() async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(
        today.year - 18,
        today.month,
        today.day,
      ),
      firstDate: DateTime(1900),
      lastDate: today,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      dateOfBirth = selected;
      is18Plus = _calculateAge(selected) >= 18;
    });
  }

  Future<Position?> getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        showMessage('Please turn ON location services.');
        return null;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showMessage('Location permission denied.');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage(
          'Location permission is blocked. Enable it in phone settings.',
        );
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (e) {
      showMessage('Location error: $e');
      return null;
    }
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (image == null) {
      return;
    }

    setState(() {
      profileImage = File(image.path);
    });
  }

  Future<void> createAccount() async {
    if (loading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty) {
      showMessage('Please enter your name.');
      return;
    }

    if (dateOfBirth == null) {
      showMessage('Please select your date of birth.');
      return;
    }

    if (age < 18 || !is18Plus) {
      showMessage('You must confirm that you are 18 or older.');
      return;
    }

    if (gender == null || gender!.isEmpty) {
      showMessage('Please select your gender.');
      return;
    }

    if (email.isEmpty) {
      showMessage('Please enter your email.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      showMessage('Creating account...');

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Firebase Auth is not responding. Check internet/Firebase setup.',
          );
        },
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Firebase account was not created.');
      }

      showMessage('Account created. Saving profile...');

      String? photoUrl;

      if (profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user.uid}.jpg');

        await storageRef.putFile(profileImage!);
        photoUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': photoUrl,
        'uid': user.uid,
        'name': name,
        'email': email,
        'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
        'age': age,
        'gender': gender,
        'is18Plus': true,
        'profileComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Firestore is not responding. Check Firestore setup/internet.',
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      showMessage('Account created successfully ❤️');

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      showMessage('Auth error: ${e.code}');
    } on FirebaseException catch (e) {
      setLoading(false);
      showMessage('Firestore error: ${e.code}');
    } catch (e) {
      setLoading(false);
      showMessage(e.toString());
    }
  }

  void setLoading(bool value) {
    if (!mounted) {
      return;
    }

    setState(() {
      loading = value;
    });
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF4F81),
              Color(0xFFFF758C),
              Color(0xFFFFA07A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: loading ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 65,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _textField(
                  controller: nameController,
                  label: 'Full name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 15),
                InkWell(
                  onTap: loading ? null : selectDateOfBirth,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: const Icon(
                        Icons.calendar_month,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      dateOfBirth == null
                          ? 'Select date of birth'
                          : '${dateOfBirth!.day}/'
                              '${dateOfBirth!.month}/'
                              '${dateOfBirth!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CheckboxListTile(
                    value: is18Plus,
                    activeColor: Colors.pink,
                    title: const Text(
                      'I am 18 or older',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: dateOfBirth == null
                        ? const Text('Select DOB first')
                        : Text('Age: $age'),
                    onChanged: loading || dateOfBirth == null
                        ? null
                        : (value) {
                            setState(() {
                              is18Plus = value ?? false;
                            });
                          },
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            gender = value;
                          });
                        },
                ),
                const SizedBox(height: 15),
                _textField(
                  controller: emailController,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  enabled: !loading,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: loading ? null : pickProfileImage,
                    child: CircleAvatar(
                      radius: 65,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImage != null
                          ? FileImage(profileImage!)
                          : null,
                      child: profileImage == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Colors.pink,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: loading ? null : pickProfileImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text(
                      profileImage == null
                          ? 'Choose Profile Photo'
                          : 'Change Profile Photo',
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              color: Colors.pink,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      color: Colors.white,
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

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: !loading,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
