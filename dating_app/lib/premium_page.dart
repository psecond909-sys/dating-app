import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const String monthlyId = 'premium_monthly';
  static const String yearlyId = 'premium_yearly';

  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _loading = true;
  bool _isPremium = false;

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
      monthlyId,
      yearlyId,
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

        setState(() {
          _isPremium = true;
        });

        _showMessage('🎉 Premium activated!');
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

            const SizedBox(height: 30),

            if (_isPremium)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.verified,
                        size: 50,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'You are Premium ⭐',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
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

            if (!_loading && !_isPremium) ...[
              _planCard(
                title: 'Premium Monthly',
                price: '₹199 / month',
                productId: monthlyId,
              ),

              const SizedBox(height: 15),

              _planCard(
                title: 'Premium Yearly',
                price: '₹1,499 / year',
                productId: yearlyId,
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
