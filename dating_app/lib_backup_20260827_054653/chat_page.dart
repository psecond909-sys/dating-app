import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherName;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final messageController = TextEditingController();
  Timer? typingTimer;

  String get myUid => FirebaseAuth.instance.currentUser!.uid;

  String get chatId {
    final ids = [myUid, widget.otherUserId]..sort();
    return ids.join('_');
  }

  DocumentReference<Map<String, dynamic>> get myUser =>
      FirebaseFirestore.instance.collection('users').doc(myUid);

  DocumentReference<Map<String, dynamic>> get otherUser =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId);

  Future<void> setPresence({
    required bool online,
    required bool typing,
  }) async {
    await myUser.set({
      'isOnline': online,
      'isTyping': typing,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    messageController.clear();

    await setPresence(
      online: true,
      typing: false,
    );

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': myUid,
      'receiverId': widget.otherUserId,
      'message': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void typingChanged() {
    final hasText =
        messageController.text.trim().isNotEmpty;

    setPresence(
      online: true,
      typing: hasText,
    );

    typingTimer?.cancel();

    if (hasText) {
      typingTimer = Timer(
        const Duration(seconds: 3),
        () {
          setPresence(
            online: true,
            typing: false,
          );
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();

    setPresence(
      online: true,
      typing: false,
    );

    messageController.addListener(typingChanged);
  }

  @override
  void dispose() {
    typingTimer?.cancel();

    setPresence(
      online: false,
      typing: false,
    );

    messageController.removeListener(typingChanged);
    messageController.dispose();

    super.dispose();
  }

  String presenceText(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return 'Offline';

    if (data['isTyping'] == true) {
      return 'typing...';
    }

    if (data['isOnline'] == true) {
      return 'Online';
    }

    final lastSeen = data['lastSeen'];

    if (lastSeen is Timestamp) {
      final difference =
          DateTime.now().difference(lastSeen.toDate());

      if (difference.inMinutes < 1) {
        return 'Last seen just now';
      }

      if (difference.inMinutes < 60) {
        return 'Last seen ${difference.inMinutes}m ago';
      }

      if (difference.inHours < 24) {
        return 'Last seen ${difference.inHours}h ago';
      }

      return 'Last seen ${difference.inDays}d ago';
    }

    return 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: otherUser.snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data()
                as Map<String, dynamic>?;

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(widget.otherName),
                Text(
                  presenceText(data),
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load messages.',
                    ),
                  );
                }

                final messages =
                    snapshot.data?.docs ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data =
                        messages[index].data()
                            as Map<String, dynamic>;

                    final mine =
                        data['senderId'] == myUid;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(
                          vertical: 4,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? Colors.pink.shade100
                              : Colors.grey.shade200,
                          borderRadius:
                              BorderRadius.circular(18),
                        ),
                        child: Text(
                          data['message'] ?? '',
                          style:
                              const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration:
                          const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) =>
                          sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sendMessage,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
