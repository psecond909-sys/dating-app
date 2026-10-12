import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Lovira Privacy Policy',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),

            Text(
              '1. Information We Collect',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lovira may collect information that you provide when creating '
              'and using your account, such as your name, age, gender, email address, '
              'location information, profile photo, likes, matches, and messages.',
            ),

            SizedBox(height: 20),

            Text(
              '2. How We Use Information',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We use information to provide dating and matching features, '
              'display profiles, provide messaging, maintain account security, '
              'prevent abuse, and improve Lovira.',
            ),

            SizedBox(height: 20),

            Text(
              '3. Location Information',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'If you grant location permission, Lovira may use your location '
              'to provide location-related dating features. You can manage location '
              'permission through your device settings.',
            ),

            SizedBox(height: 20),

            Text(
              '4. Photos and User Content',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Photos, profile information, and messages that you submit may be '
              'stored and processed to provide app functionality and safety features.',
            ),

            SizedBox(height: 20),

            Text(
              '5. Firebase and Service Providers',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lovira uses third-party services such as Firebase to provide '
              'authentication, database, storage, and other app services. '
              'Information may be processed by these services as necessary to '
              'provide Lovira functionality.',
            ),

            SizedBox(height: 20),

            Text(
              '6. Account Deletion',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You can request deletion of your Lovira account using the '
              'Delete Account option in the app. Some information may need to be '
              'retained when required by law or for legitimate security purposes.',
            ),

            SizedBox(height: 20),

            Text(
              '7. Security',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We take reasonable measures to protect information used by Lovira. '
              'However, no online service can guarantee absolute security.',
            ),

            SizedBox(height: 20),

            Text(
              '8. Children',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lovira is intended for adults aged 18 and above. Children and '
              'minors are not permitted to use the dating functionality.',
            ),

            SizedBox(height: 20),

            Text(
              '9. Changes to This Policy',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We may update this Privacy Policy when the app, services, or legal '
              'requirements change. Updated information should be provided through '
              'the appropriate Lovira privacy policy location.',
            ),

            SizedBox(height: 30),

            Text(
              'Last updated: September 2026',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
