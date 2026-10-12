import 'dart:io';
import 'premium_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  final String userName;

  const ChatPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _blocked = false;
  bool _matched = false;
  final messageController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();

  bool showEmojiPicker = false;
  bool sendingImage = false;
  bool isTyping = false;

  String get chatId {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return '';
    }

    final ids = [currentUser.uid, widget.userId]..sort();

    return ids.join('_');
  }

  Future<void> _checkMatchStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final myMatch = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matches')
          .doc(widget.userId)
          .get();

      final theirMatch = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('matches')
          .doc(currentUser.uid)
          .get();

      final isMutualMatch = myMatch.exists && theirMatch.exists;

      if (!mounted) return;

      setState(() {
        _matched = isMutualMatch;
      });
    } catch (e) {
      debugPrint('Match status error: $e');
    }
  }

  Future<bool> _isMutualMatch() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || widget.userId.isEmpty) {
      return false;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final myMatch = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matches')
          .doc(widget.userId)
          .get();

      if (!myMatch.exists) {
        return false;
      }

      final theirMatch = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('matches')
          .doc(currentUser.uid)
          .get();

      return theirMatch.exists;
    } catch (e) {
      debugPrint('Mutual match check error: $e');
      return false;
    }
  }

  Future<void> _checkBlockedStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final iBlockedThem = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(widget.userId)
          .get();

      final theyBlockedMe = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('blockedUsers')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _blocked = iBlockedThem.exists || theyBlockedMe.exists;
      });
    } catch (e) {
      debugPrint('Block status error: $e');
    }
  }

  Future<void> updateTypingStatus(bool typing) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({
        'typing_${currentUser.uid}': typing,
      }, SetOptions(merge: true));
    } catch (_) {
      // Typing status should never interrupt messaging.
    }
  }

  void _openPremiumPlans() {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PremiumPage(),
      ),
    );
  }

  Future<bool> canSendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return false;
    }

    final firestore = FirebaseFirestore.instance;

    final userDoc = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final plan = userDoc.data()?['plan']?.toString().toLowerCase() ?? 'free';

    // Silver and Premium users have unlimited chat.
    if (plan == 'silver' || plan == 'premium') {
      return true;
    }

    // Free users:
    // - 15 messages/day when mutually matched.
    // - 5 messages/day before a mutual match.
    final matched = await _isMutualMatch();
    final dailyLimit = matched ? 15 : 5;

    final today = DateTime.now();

    final dayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final counterRef = firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('dailyMessageCounts')
        .doc('${widget.userId}_$dayKey');

    final counter = await counterRef.get();

    final count = (counter.data()?['count'] as num?)?.toInt() ?? 0;

    if (count >= dailyLimit) {
      if (mounted) {
        final limit = matched ? 15 : 5;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have reached your $limit message daily limit. '
              'Upgrade to Silver 🥈 or Premium ⭐ for unlimited chat.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UPGRADE',
              onPressed: _openPremiumPlans,
            ),
          ),
        );
      }

      return false;
    }

    return true;
  }

  Future<void> recordMessageSent() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    final matched = await _isMutualMatch();

    if (matched) {
      return;
    }

    final today = DateTime.now();

    final dayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final counterRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('dailyMessageCounts')
        .doc('${widget.userId}_$dayKey');

    await counterRef.set({
      'count': FieldValue.increment(1),
      'date': dayKey,
      'userId': widget.userId,
    }, SetOptions(merge: true));
  }

  Future<bool> _isBlocked() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return true;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final iBlockedThem = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(widget.userId)
          .get();

      if (iBlockedThem.exists) {
        return true;
      }

      final theyBlockedMe = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('blockedUsers')
          .doc(currentUser.uid)
          .get();

      return theyBlockedMe.exists;
    } catch (e) {
      debugPrint('Block check error: $e');
      return false;
    }
  }

  Future<void> sendMessage() async {
    final blocked = await _isBlocked();

    if (blocked) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You cannot message this user.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = messageController.text.trim();

    await updateTypingStatus(false);
    isTyping = false;

    if (text.isEmpty) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    final allowed = await canSendMessage();

    if (!allowed) {
      return;
    }

    messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': widget.userId,
        'text': text,
        'type': 'text',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await recordMessageSent();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message error: $e'),
        ),
      );
    }
  }

  Future<void> pickAndSendImage() async {
    final blocked = await _isBlocked();

    if (blocked) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You cannot message this user.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    final allowed = await canSendMessage();

    if (!allowed) {
      return;
    }

    try {
      final XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        sendingImage = true;
      });

      final file = File(pickedFile.path);

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child(fileName);

      await storageRef.putFile(file);

      final imageUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': widget.userId,
        'text': '',
        'imageUrl': imageUrl,
        'type': 'image',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await recordMessageSent();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sendingImage = false;
        });
      }
    }
  }

  Widget messageBubble(
    String text,
    bool mine, {
    String? imageUrl,
    DateTime? timestamp,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
        ),
        margin: const EdgeInsets.only(
          left: 10,
          right: 10,
          bottom: 10,
        ),
        padding: EdgeInsets.all(hasImage ? 5 : 16),
        decoration: BoxDecoration(
          color: mine ? Colors.pink : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 4),
            bottomRight: Radius.circular(mine ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  width: 260,
                  height: 260,
                  fit: BoxFit.cover,
                  loadingBuilder: (
                    context,
                    child,
                    loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const SizedBox(
                      width: 260,
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.pink,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 260,
                      height: 120,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 45,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              )
            : Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: mine ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: mine
                            ? Colors.white70
                            : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  void toggleEmojiPicker() {
    FocusScope.of(context).unfocus();

    setState(() {
      showEmojiPicker = !showEmojiPicker;
    });
  }

  Future<void> updateOnlineStatus(bool online) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Do not interrupt chat if status update fails.
    }
  }

  Future<void> markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      if (messages.docs.isEmpty) {
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final message in messages.docs) {
        batch.update(message.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (_) {
      // Read receipts should not interrupt the chat.
    }
  }

  Future<void> ensureChatExists() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    final ids = [currentUser.uid, widget.userId]..sort();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({
        'users': ids,
        'user1': ids[0],
        'user2': ids[1],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Ensure chat error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkMatchStatus();
    _checkBlockedStatus();
    updateOnlineStatus(true);
    ensureChatExists();
    markMessagesAsRead();

    messageController.addListener(() {
      final typing = messageController.text.trim().isNotEmpty;

      if (typing != isTyping) {
        isTyping = typing;
        updateTypingStatus(typing);
      }
    });
  }

  @override
  void dispose() {
    updateTypingStatus(false);
    updateOnlineStatus(false);
    messageController.dispose();
    super.dispose();
  }

  Future<void> _showDeleteChatDialog() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Chat?'),
          content: const Text(
            'This will delete the messages in this chat. '
            'The person and your match will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final messages = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      if (messages.docs.isNotEmpty) {
        final batch = firestore.batch();

        for (final message in messages.docs) {
          batch.delete(message.reference);
        }

        await batch.commit();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showRemoveMatchDialog() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Match?'),
          content: const Text(
            'This will remove the match and delete this chat. '
            'Both profiles will remain available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Remove the match from both users.
      final myMatchRef = firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matches')
          .doc(widget.userId);

      final otherMatchRef = firestore
          .collection('users')
          .doc(widget.userId)
          .collection('matches')
          .doc(currentUser.uid);

      // Delete all messages in this chat.
      final messages = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = firestore.batch();

      batch.delete(myMatchRef);
      batch.delete(otherMatchRef);

      for (final message in messages.docs) {
        batch.delete(message.reference);
      }

      // Delete the main match document too.
      final ids = [currentUser.uid, widget.userId]..sort();
      final matchId = ids.join('_');

      batch.delete(
        firestore.collection('matches').doc(matchId),
      );

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove match: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showReportDialog() async {
    String? selectedReason;

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report User'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Why are you reporting this user?',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Reason',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Harassment or bullying',
                        child: Text('Harassment or bullying'),
                      ),
                      DropdownMenuItem(
                        value: 'Fake profile',
                        child: Text('Fake profile'),
                      ),
                      DropdownMenuItem(
                        value: 'Inappropriate content',
                        child: Text('Inappropriate content'),
                      ),
                      DropdownMenuItem(
                        value: 'Spam or scam',
                        child: Text('Spam or scam'),
                      ),
                      DropdownMenuItem(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedReason),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .add({
        'reportedUserId': widget.userId,
        'reportedUserName': widget.userName,
        'reportedBy': currentUser.uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit report: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showBlockDialog() async {
    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),
          content: const Text(
            'This will block this user, remove the match, '
            'and delete this chat. You will no longer be able '
            'to message each other.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Block',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldBlock != true) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Add this user to my blockedUsers collection.
      final blockedUserRef = firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(widget.userId);

      // Remove the match from both users.
      final myMatchRef = firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('matches')
          .doc(widget.userId);

      final otherMatchRef = firestore
          .collection('users')
          .doc(widget.userId)
          .collection('matches')
          .doc(currentUser.uid);

      // Find the main match document.
      final ids = [currentUser.uid, widget.userId]..sort();
      final matchId = ids.join('_');

      final mainMatchRef = firestore
          .collection('matches')
          .doc(matchId);

      // Delete all messages in this chat.
      final messages = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = firestore.batch();

      batch.set(
        blockedUserRef,
        {
          'userId': widget.userId,
          'blockedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.delete(myMatchRef);
      batch.delete(otherMatchRef);
      batch.delete(mainMatchRef);

      for (final message in messages.docs) {
        batch.delete(message.reference);
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _blocked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User blocked.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to block user: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login again.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteChatDialog();
              } else if (value == 'remove_match') {
                _showRemoveMatchDialog();
              } else if (value == 'block') {
                _showBlockDialog();
              } else if (value == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete Chat'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'remove_match',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.heart_broken_outlined),
                  title: Text('Remove Match'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block),
                  title: Text('Block User'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'report',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report User'),
                ),
              ),
            ],
          ),
        ],
        title: Row(
          children: [
            const CircleAvatar(
              radius: 21,
              backgroundColor: Color(0xFFFFE0E6),
              child: Icon(
                Icons.person,
                color: Colors.pink,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _matched ? 'Matched ❤️' : 'Like ❤️',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.pink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  Future.microtask(markMessagesAsRead);
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
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
                        'Unable to load messages.\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start the conversation ❤️',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 20,
                    bottom: 10,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();

                    final text =
                        data['text'] as String? ?? '';

                    final imageUrl =
                        data['imageUrl'] as String?;

                    final senderId =
                        data['senderId'] as String? ?? '';

                    final timestampValue = data['createdAt'];
                    final timestamp = timestampValue is Timestamp
                        ? timestampValue.toDate()
                        : null;

                    return messageBubble(
                      text,
                      senderId == currentUser.uid,
                      imageUrl: imageUrl,
                      timestamp: timestamp,
                    );
                  },
                );
              },
            ),
          ),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();

              if (data == null) {
                return const SizedBox.shrink();
              }

              final currentUid =
                  FirebaseAuth.instance.currentUser?.uid ?? '';

              final otherTyping =
                  data['typing_${widget.userId}'] == true;

              if (!otherTyping || currentUid == widget.userId) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(
                  left: 18,
                  bottom: 5,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.userName} is typing...',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            },
          ),

          if (sendingImage)
            const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.pink,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Uploading image...'),
                ],
              ),
            ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                8,
                8,
                8,
                8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Color(0x22000000),
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: sendingImage
                        ? null
                        : pickAndSendImage,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.pink,
                    ),
                  ),

                  IconButton(
                    onPressed: toggleEmojiPicker,
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.pink,
                    ),
                  ),

                  Expanded(
                    child: TextField(
                      controller: messageController,
                      enabled: !_blocked,
                      textInputAction: TextInputAction.send,
                      onTap: () {
                        if (showEmojiPicker) {
                          setState(() {
                            showEmojiPicker = false;
                          });
                        }
                      },
                      onSubmitted: (_) {
                        sendMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFFFFF1F4),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.pink,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _blocked ? null : sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (showEmojiPicker)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  messageController.text =
                      messageController.text + emoji.emoji;

                  messageController.selection =
                      TextSelection.fromPosition(
                    TextPosition(
                      offset: messageController.text.length,
                    ),
                  );
                },
                config: const Config(
                  height: 280,
                  checkPlatformCompatibility: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
