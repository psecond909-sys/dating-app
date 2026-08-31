import 'dart:io';

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
  final messageController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();

  bool showEmojiPicker = false;
  bool sendingImage = false;

  String get chatId {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return '';
    }

    final ids = [currentUser.uid, widget.userId]..sort();

    return ids.join('_');
  }

  Future<bool> canSendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return false;
    }

    final firestore = FirebaseFirestore.instance;

    final matchRef = firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('matches')
        .doc(widget.userId);

    final match = await matchRef.get();

    if (match.exists) {
      return true;
    }

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

    if (count >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have used your 5 messages for today. '
              'If they like you back, you can chat unlimited ❤️',
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

    final matchRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('matches')
        .doc(widget.userId);

    final match = await matchRef.get();

    if (match.exists) {
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

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

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

  Future<void> ensureChatExists() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || chatId.isEmpty) {
      return;
    }

    final ids = [currentUser.uid, widget.userId]..sort();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({
      'users': ids,
      'user1': ids[0],
      'user2': ids[1],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void initState() {
    super.initState();
    updateOnlineStatus(true);
    ensureChatExists();
  }

  @override
  void dispose() {
    updateOnlineStatus(false);
    messageController.dispose();
    super.dispose();
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
                const Text(
                  'Matched ❤️',
                  style: TextStyle(
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
                      onPressed: sendMessage,
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
