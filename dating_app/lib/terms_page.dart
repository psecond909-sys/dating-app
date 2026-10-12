import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Community Guidelines'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Lovira Terms & Community Guidelines',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),

            Text(
              '1. Eligibility',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lovira is intended for adults aged 18 and above. '
              'You must provide accurate information when creating your account.',
            ),

            SizedBox(height: 20),

            Text(
              '2. Respect Others',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Treat other users with respect. Harassment, bullying, threats, '
              'hate, intimidation, and abusive behavior are not allowed.',
            ),

            SizedBox(height: 20),

            Text(
              '3. No Sexual Exploitation or Child Abuse',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Any sexual content involving minors, child sexual abuse material, '
              'sexual exploitation, or attempts to exploit children is strictly prohibited '
              'and may be reported to the appropriate authorities.',
            ),

            SizedBox(height: 20),

            Text(
              '4. Profile Photos',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Only upload photos and content that you have the right to use. '
              'Do not upload illegal, abusive, violent, hateful, or sexually exploitative content.',
            ),

            SizedBox(height: 20),

            Text(
              '5. Messaging',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Do not use messaging to threaten, harass, scam, impersonate, '
              'or sexually exploit another person.',
            ),

            SizedBox(height: 20),

            Text(
              '6. Reporting and Blocking',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Use the available reporting and blocking features when you encounter '
              'inappropriate behavior or content.',
            ),

            SizedBox(height: 20),

            Text(
              '7. Enforcement',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lovira may remove content, restrict features, suspend accounts, '
              'or permanently remove accounts that violate these guidelines.',
            ),

            SizedBox(height: 20),

            Text(
              '8. Safety',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Never share passwords, financial information, or other sensitive '
              'information with people you meet through the app. Meet people safely '
              'and use your best judgment.',
            ),

            SizedBox(height: 30),

            Text(
              'By using Lovira, you agree to follow these Terms & Community Guidelines.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
