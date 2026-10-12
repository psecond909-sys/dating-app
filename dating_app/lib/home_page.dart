import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:geolocator/geolocator.dart';
import 'terms_page.dart';
import 'privacy_policy_page.dart';
import 'premium_page.dart';

import 'matches_page.dart';
import 'chat_page.dart';
import 'likes_received_page.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int selectedIndex = 0;
  Timer? _presenceTimer;

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _setOnline();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _setOnline(),
    );
  }

  void _stopPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPresenceHeartbeat();
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPresenceHeartbeat();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPresenceHeartbeat();
      _setOffline();
    }
  }

  Future<void> _setOnline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Online status error: $e');
    }
  }

  Future<void> _setOffline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Offline status error: $e');
    }
  }

  @override
  void dispose() {
    _stopPresenceHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-9798641582173027/2056471596',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
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
  Set<String> blockedUserIds = {};

  int _swipeCount = 0;
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  bool _isPremium = false;
  bool _premiumChecked = false;

  Position? currentPosition;
  bool locationLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _loadCurrentLocation();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _premiumChecked = true;
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();
      final plan = (data?['plan'] ?? 'free').toString().toLowerCase();

      final premium = plan == 'premium';

      if (!mounted) return;

      setState(() {
        _isPremium = premium;
        _premiumChecked = true;
      });

      if (!premium) {
        _loadInterstitialAd();
      }
    } catch (e) {
      debugPrint('Premium status error: $e');

      if (!mounted) return;

      setState(() {
        _isPremium = false;
        _premiumChecked = true;
      });

      _loadInterstitialAd();
    }
  }

  void _loadInterstitialAd() {
    if (_isPremium) {
      return;
    }

    if (_isLoadingInterstitial || _interstitialAd != null) {
      return;
    }

    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-9798641582173027/7143830093',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;

          if (!mounted) {
            ad.dispose();
            return;
          }

          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          debugPrint('Interstitial ad failed: $error');
        },
      ),
    );
  }

  Future<void> _registerSwipe() async {
    if (_isPremium) {
      return;
    }

    _swipeCount++;

    debugPrint('Profile swipe count: $_swipeCount');

    if (_swipeCount < 5) {
      return;
    }

    _swipeCount = 0;

    final ad = _interstitialAd;

    if (ad == null) {
      _loadInterstitialAd();
      return;
    }

    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial show failed: $error');
        ad.dispose();
        _loadInterstitialAd();
      },
    );

    ad.show();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            locationLoading = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            locationLoading = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentPosition = position;
        locationLoading = false;
      });
    } catch (e) {
      debugPrint('Current location error: $e');

      if (mounted) {
        setState(() {
          locationLoading = false;
        });
      }
    }
  }

  Future<void> _loadBlockedUsers() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('blockedUsers')
          .get();

      if (!mounted) return;

      setState(() {
        blockedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      debugPrint('Unable to load blocked users: $e');
    }
  }

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
                        !passedUserIds.contains(doc.id) &&
                        !blockedUserIds.contains(doc.id);
                  }).toList();

                  profiles.sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();

                    final aLat = (aData['latitude'] as num?)?.toDouble();
                    final aLng = (aData['longitude'] as num?)?.toDouble();
                    final bLat = (bData['latitude'] as num?)?.toDouble();
                    final bLng = (bData['longitude'] as num?)?.toDouble();

                    if (currentPosition == null) {
                      return 0;
                    }

                    if (aLat == null || aLng == null) {
                      return 1;
                    }

                    if (bLat == null || bLng == null) {
                      return -1;
                    }

                    final aDistance = Geolocator.distanceBetween(
                      currentPosition!.latitude,
                      currentPosition!.longitude,
                      aLat,
                      aLng,
                    );

                    final bDistance = Geolocator.distanceBetween(
                      currentPosition!.latitude,
                      currentPosition!.longitude,
                      bLat,
                      bLng,
                    );

                    return aDistance.compareTo(bDistance);
                  });

                  // Always keep a few clearly marked demo profiles
                  // available for testing the Discover screen.
                  const demoProfiles = [
                    {
                      'id': 'demo_0',
                      'name': 'Aisha',
                      'age': 24,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 0.0,
                      'photoAsset': 'assets/profiles/profile1.png',
                    },
                    {
                      'id': 'demo_1',
                      'name': 'Priya',
                      'age': 26,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 1.0,
                      'photoAsset': 'assets/profiles/profile2.png',
                    },
                    {
                      'id': 'demo_2',
                      'name': 'Ananya',
                      'age': 23,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 2.0,
                      'photoAsset': 'assets/profiles/profile3.png',
                    },
                    {
                      'id': 'demo_3',
                      'name': 'Rohini',
                      'age': 27,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 3.0,
                      'photoAsset': 'assets/profiles/profile4.png',
                    },
                    {
                      'id': 'demo_4',
                      'name': 'Aravinda',
                      'age': 25,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 4.0,
                      'photoAsset': 'assets/profiles/profile5.png',
                    },
                    {
                      'id': 'demo_5',
                      'name': 'Kavya',
                      'age': 24,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 5.0,
                      'photoAsset': 'assets/profiles/profile6.png',
                    },
                    {
                      'id': 'demo_6',
                      'name': 'Meera',
                      'age': 28,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 6.0,
                      'photoAsset': 'assets/profiles/profile7.png',
                    },
                    {
                      'id': 'demo_7',
                      'name': 'Sneha',
                      'age': 26,
                      'city': 'Nearby',
                      'gender': 'Female',
                      'distanceKm': 7.0,
                      'photoAsset': 'assets/profiles/profile8.png',
                    },
                  ];

                  return ListView.builder(
                    itemCount: profiles.length + demoProfiles.length,
                    itemBuilder: (context, index) {
                      // Real Firebase profiles first.
                      if (index < profiles.length) {
                        final doc = profiles[index];
                        final data = doc.data();

                        double? distanceKm;

                        if (currentPosition != null) {
                          final lat = (data['latitude'] as num?)?.toDouble();
                          final lng = (data['longitude'] as num?)?.toDouble();

                          if (lat != null && lng != null) {
                            final meters = Geolocator.distanceBetween(
                              currentPosition!.latitude,
                              currentPosition!.longitude,
                              lat,
                              lng,
                            );

                            distanceKm = meters / 1000;
                          }
                        }

                        return ProfileCard(
                          key: ValueKey(doc.id),
                          userId: doc.id,
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
                          isOnline: data['isOnline'] == true,
                          lastSeen: data['lastSeen'],
                          distanceKm: distanceKm,
                          onPassed: () {
                            setState(() {
                              passedUserIds.add(doc.id);
                            });

                            _registerSwipe();
                          },
                        );
                      }

                      // Demo/test profiles.
                      final demo = demoProfiles[index - profiles.length];

                      return ProfileCard(
                        key: ValueKey(demo['id']),
                        userId: demo['id'] as String,
                        name: demo['name'] as String,
                        age: demo['age'] as int,
                        city: demo['city'] as String,
                        gender: demo['gender'] as String,
                        photoAsset: demo['photoAsset'] as String?,
                        distanceKm: (demo['distanceKm'] as num).toDouble(),
                        isOnline: true,
                        onPassed: () {
                          setState(() {
                            passedUserIds.add(demo['id'] as String);
                          });

                          _registerSwipe();
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_premiumChecked && !_isPremium) ...[
              const SizedBox(height: 8),
              const Center(
                child: AdBanner(),
              ),
            ],
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
  final String? photoAsset;
  final String? gender;
  final bool isOnline;
  final dynamic lastSeen;
  final double? distanceKm;
  final VoidCallback? onPassed;

  const ProfileCard({
    super.key,
    required this.userId,
    required this.name,
    required this.age,
    required this.city,
    this.photoUrl,
    this.photoAsset,
    this.gender,
    this.isOnline = false,
    this.lastSeen,
    this.distanceKm,
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

  Future<void> pingUser(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('pings')
          .doc(userId)
          .set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            userId: userId,
            userName: name,
          ),
        ),
      );

      if (!context.mounted) {
        return;
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ping error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> likeUser(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      // Fake/demo profiles are local app profiles, not Firebase users.
      // They automatically like the current user back, creating a match.
      final isFakeProfile = userId.startsWith('demo_');

      if (isFakeProfile) {
        final ids = [currentUser.uid, userId]..sort();
        final matchId = ids.join('_');

        // Save the match for the real signed-in user only.
        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('matches')
            .doc(userId)
            .set({
          'userId': userId,
          'matchId': matchId,
          'name': name,
          'isDemo': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save the top-level match. The signed-in user is a member,
        // so this is allowed by the Firestore rules.
        await firestore.collection('matches').doc(matchId).set({
          'users': ids,
          'createdAt': FieldValue.serverTimestamp(),
          'isDemo': true,
        });

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("It's a match with $name! ❤️"),
            behavior: SnackBarBehavior.floating,
          ),
        );

        onPassed?.call();
        return;
      }

      // -----------------------------
      // REAL FIREBASE USER
      // -----------------------------

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
      debugPrint('LIKE STEP 1: saving myLike');
      try {
        await myLikeRef.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('LIKE STEP 1 SUCCESS');
      } catch (e) {
        debugPrint('LIKE STEP 1 FAILED: $e');
        rethrow;
      }

      // Notify the other real user.
      debugPrint('LIKE STEP 2: saving receivedLike');
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('receivedLikes')
            .doc(currentUser.uid)
            .set({
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('LIKE STEP 2 SUCCESS');
      } catch (e) {
        debugPrint('LIKE STEP 2 FAILED: $e');
        rethrow;
      }

      // Check whether they already liked me.
      debugPrint('LIKE STEP 3: checking otherLike');
      late final DocumentSnapshot<Map<String, dynamic>> otherLike;
      try {
        otherLike = await otherLikeRef.get();
        debugPrint('LIKE STEP 3 SUCCESS');
      } catch (e) {
        debugPrint('LIKE STEP 3 FAILED: $e');
        rethrow;
      }

      if (otherLike.exists) {
        // MUTUAL LIKE = MATCH ❤️
        final ids = [currentUser.uid, userId]..sort();
        final matchId = ids.join('_');

        await firestore.collection('matches').doc(matchId).set({
          'users': ids,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save match for both real users.
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
            content: Text('You liked $name ❤️'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      onPassed?.call();
    } catch (e, stack) {
      debugPrint('LIKE ERROR: $e');
      debugPrint('LIKE STACK: $stack');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('LIKE ERROR: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> reportUser(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid == userId) {
      return;
    }

    final reasons = [
      'Fake profile',
      'Harassment or abusive behavior',
      'Inappropriate photo',
      'Spam or scam',
      'Other',
    ];

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((item) {
              return ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: Text(item),
                onTap: () => Navigator.pop(dialogContext, item),
              );
            }).toList(),
          ),
        );
      },
    );

    if (reason == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentUser.uid,
        'reportedUserId': userId,
        'reportedUserName': name,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Report submitted. Thank you for helping keep LoveMatch safe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Report error: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit report: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatLastSeen(dynamic timestamp) {
    if (timestamp is! Timestamp) {
      return 'Last seen recently';
    }

    final lastSeenTime = timestamp.toDate();
    final difference = DateTime.now().difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    }

    if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours} hr ago';
    }

    if (difference.inDays == 1) {
      return 'Last seen yesterday';
    }

    return 'Last seen ${difference.inDays} days ago';
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
          // Online / Last Seen status
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online' : _formatLastSeen(lastSeen),
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

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
            child: photoAsset != null && photoAsset!.isNotEmpty
                ? Image.asset(
                    photoAsset!,
                    width: double.infinity,
                    height: 330,
                    fit: BoxFit.cover,
                  )
                : photoUrl != null && photoUrl!.isNotEmpty
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
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    if (distanceKm != null) ...[
                      const SizedBox(width: 10),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${distanceKm!.toStringAsFixed(distanceKm! < 1 ? 1 : 0)} km away',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ],
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
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 42),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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
                            size: 17,
                          ),
                          label: const Text(
                            'Pass',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 42),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => likeUser(context),
                          icon: const Icon(
                            Icons.favorite,
                            size: 17,
                          ),
                          label: const Text(
                            'Like',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 42),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => pingUser(context),
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 17,
                          ),
                          label: const Text(
                            'Ping',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => reportUser(context),
                    icon: const Icon(
                      Icons.flag_outlined,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Report User',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
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
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Logout offline status error: $e');
      }
    }

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

  Future<void> deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This will permanently delete your LoveMatch account and profile. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Delete the user's main profile document.
      await firestore.collection('users').doc(user.uid).delete();

      // Delete the Firebase Authentication account.
      await user.delete();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      String message;

      if (e.code == 'requires-recent-login') {
        message =
            'For security, please log out, log in again, and then delete your account.';
      } else {
        message = 'Could not delete account: ${e.message ?? e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Delete account error: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                (now.month == birthDate.month && now.day < birthDate.day)) {
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
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
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
                        onPressed: uploadingPhoto ? null : changeProfilePhoto,
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
                  onPressed: uploadingPhoto ? null : changeProfilePhoto,
                  icon: const Icon(
                    Icons.photo_library,
                    color: Colors.pink,
                  ),
                  label: Text(
                    uploadingPhoto ? 'Uploading...' : 'Change Profile Picture',
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
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PremiumPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text('Premium Plans ⭐'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.privacy_tip,
                      color: Colors.pink,
                    ),
                    label: const Text('Privacy Policy'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.gavel,
                      color: Colors.pink,
                    ),
                    label: const Text('Terms & Community Guidelines'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => deleteAccount(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
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
