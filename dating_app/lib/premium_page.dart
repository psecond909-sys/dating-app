import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const String silverMonthlyId = 'silver_monthly';
  static const String silverYearlyId = 'silver_yearly';
  static const String premiumMonthlyId = 'premium_monthly';
  static const String premiumYearlyId = 'premium_yearly';

  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _loading = true;
  String _plan = 'free';

  Future<void> _loadSavedPlan() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) {
        return;
      }

      final savedPlan = doc.data()?['plan'];

      if (savedPlan == 'silver' || savedPlan == 'premium') {
        setState(() {
          _plan = savedPlan;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved plan: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('Purchase stream error: $error');
      },
    );

    _loadProducts();
    _loadSavedPlan();
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();

    if (!mounted) {
      return;
    }

    if (!available) {
      setState(() {
        _storeAvailable = false;
        _loading = false;
      });
      return;
    }

    const ids = <String>{
      silverMonthlyId,
      silverYearlyId,
      premiumMonthlyId,
      premiumYearlyId,
    };

    final response = await _iap.queryProductDetails(ids);

    if (!mounted) {
      return;
    }

    if (response.error != null) {
      debugPrint('Product query error: ${response.error}');
    }

    setState(() {
      _storeAvailable = true;
      _products = response.productDetails;
      _loading = false;
    });

    debugPrint('Products found: ${_products.map((p) => p.id).toList()}');
  }

  Future<void> _buyProduct(String productId) async {
    if (!_storeAvailable) {
      _showMessage('Google Play Store is not available.');
      return;
    }

    ProductDetails? product;

    for (final item in _products) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }

    if (product == null) {
      _showMessage(
        'Subscription is not available yet. Please check Google Play setup.',
      );
      return;
    }

    final purchaseParam = PurchaseParam(
      productDetails: product,
    );

    try {
      await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (e) {
      debugPrint('Purchase error: $e');
      _showMessage('Unable to start purchase.');
    }
  }

  Future<void> _restorePurchases() async {
    if (!_storeAvailable) {
      _showMessage('Google Play Store is not available.');
      return;
    }

    try {
      await _iap.restorePurchases();
      _showMessage('Restore request sent. Checking your purchases...');
    } catch (e) {
      debugPrint('Restore purchases error: $e');
      _showMessage('Unable to restore purchases. Please try again.');
    }
  }

  Future<void> _savePlanToFirebase(String plan) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('Cannot save plan: user is not signed in.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'plan': plan,
        'planUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Saved plan to Firebase: $plan');
    } catch (e) {
      debugPrint('Error saving plan: $e');
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      debugPrint(
        'Purchase: ${purchase.productID} - ${purchase.status}',
      );

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (!mounted) {
          return;
        }

        String? purchasedPlan;

        if (purchase.productID == silverMonthlyId ||
            purchase.productID == silverYearlyId) {
          purchasedPlan = 'silver';
        } else if (purchase.productID == premiumMonthlyId ||
            purchase.productID == premiumYearlyId) {
          purchasedPlan = 'premium';
        }

        if (purchasedPlan != null) {
          setState(() {
            _plan = purchasedPlan!;
          });

          await _savePlanToFirebase(purchasedPlan);

          _showMessage(
            '🎉 ${purchasedPlan[0].toUpperCase()}${purchasedPlan.substring(1)} plan activated!',
          );
        }

      }

      if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
        _showMessage('Purchase failed. Please try again.');
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium ⭐'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            const Text(
              'Upgrade to Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Get more from your dating experience',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            _feature('Unlimited Likes'),
            _feature('See Who Liked You'),
            _feature('Advanced Filters'),
            _feature('Premium Chat Features'),

            const SizedBox(height: 25),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment & Subscription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Subscriptions automatically renew at the end of each billing period unless cancelled before renewal.',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'You can cancel your subscription at any time through Google Play subscription settings. Cancellation stops future renewals; your current subscription remains active until the end of the paid period.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Customer Care',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'psecond909@gmail.com',
                      style: TextStyle(
                        color: Colors.pink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (_plan != 'free')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 50,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _plan == 'silver'
                            ? 'You are Silver 🥈'
                            : 'You are Premium ⭐',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Your Plan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Upgrade when you reach your free limits.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('Feature')),
                          DataColumn(label: Text('Free')),
                          DataColumn(label: Text('Silver 🥈')),
                          DataColumn(label: Text('Premium ⭐')),
                        ],
                        rows: const [
                          DataRow(
                            cells: [
                              DataCell(Text('Likes / day')),
                              DataCell(Text('Limited')),
                              DataCell(Text('More')),
                              DataCell(Text('Unlimited')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(Text('Messages without match')),
                              DataCell(Text('5 overall*')),
                              DataCell(Text('5 overall*')),
                              DataCell(Text('Unlimited')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(Text('Messages after match')),
                              DataCell(Text('Unlimited')),
                              DataCell(Text('Unlimited')),
                              DataCell(Text('Unlimited')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(Text('Images')),
                              DataCell(Text('2')),
                              DataCell(Text('Unlimited')),
                              DataCell(Text('Unlimited')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(Text('Emoji')),
                              DataCell(Text('Included')),
                              DataCell(Text('Included')),
                              DataCell(Text('Included')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(Text('Ads')),
                              DataCell(Text('Shown')),
                              DataCell(Text('Shown')),
                              DataCell(Text('Ad Free')),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Silver 🥈',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '5 unmatched messages per person overall • Unlimited images • '
                      'Unlimited chat after a mutual match • Ads shown.',
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Premium ⭐',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Unlimited messages without a match • Unlimited messages after matching • '
                      'Unlimited images • Emoji • Ad free.',
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Subscriptions automatically renew unless cancelled. '
                      'You can cancel anytime through Google Play subscription settings.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            if (!_loading && _plan == 'free') ...[
              _planCard(
                title: 'Silver Monthly 🥈',
                price: '₹99 / month',
                productId: silverMonthlyId,
              ),

              const SizedBox(height: 15),

              _planCard(
                title: 'Silver Yearly 🥈',
                price: '₹799 / year',
                productId: silverYearlyId,
              ),

              const SizedBox(height: 25),

              _planCard(
                title: 'Premium Monthly ⭐',
                price: '₹199 / month',
                productId: premiumMonthlyId,
              ),

              const SizedBox(height: 15),

              _planCard(
                title: 'Premium Yearly ⭐',
                price: '₹1,499 / year',
                productId: premiumYearlyId,
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _restorePurchases,
                icon: const Icon(Icons.restore),
                label: const Text('Restore Purchases'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String productId,
  }) {
    ProductDetails? product;

    for (final item in _products) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }

    final buttonText = product == null
        ? 'Subscribe'
        : 'Subscribe ${product.price}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product?.price ?? price,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: product == null
                  ? null
                  : () => _buyProduct(productId),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}
