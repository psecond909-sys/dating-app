import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherName;

  const ChatPage({super.key, required this.otherUid, required this.otherName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();

  Future<void> send() async {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    controller.clear();

    await FirebaseService.sendMessage(widget.otherUid, text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseService.messages(widget.otherUid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();

                    final mine = data['senderId'] == FirebaseService.uid;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? Colors.pink.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(data['text']?.toString() ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: send,
                  icon: const Icon(Icons.send, color: Colors.pink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
