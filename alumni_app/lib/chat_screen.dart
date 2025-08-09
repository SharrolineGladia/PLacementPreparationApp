import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatScreen extends StatefulWidget {
  final String chatUserId;

  const ChatScreen({Key? key, required this.chatUserId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  String? _chatUserName;
  String? _currentUserName;

  final Color primaryColor = const Color(0xff5B75F0);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadChatUserName();
    _loadCurrentUserName();
  }

  Future<void> _loadChatUserName() async {
    final userSnapshot = await _database.child('users/${widget.chatUserId}').get();
    if (userSnapshot.exists) {
      setState(() {
        _chatUserName = userSnapshot.child('name').value as String?;
      });
    }
  }

  Future<void> _loadCurrentUserName() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final userSnapshot = await _database.child('users/$userId').get();
      if (userSnapshot.exists) {
        setState(() {
          _currentUserName = userSnapshot.child('name').value as String?;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      final chatRef = _database.child('chats/$userId/${widget.chatUserId}');

      chatRef.onValue.listen((DatabaseEvent event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          final messagesList = data.entries.map((entry) {
            return Message.fromMap(entry.value);
          }).toList();

          // Sort messages by timestamp
          messagesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          setState(() {
            _messages = messagesList;
          });
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (_messageController.text.isNotEmpty) {
      final message = Message(
        senderId: userId!,
        text: _messageController.text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Send message to both users
      await _database.child('chats/$userId/${widget.chatUserId}').push().set(message.toMap());
      await _database.child('chats/${widget.chatUserId}/$userId').push().set(message.toMap());

      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color:Colors.white),
        title: Text('${_chatUserName ?? 'Loading...'}',style: TextStyle(color:Colors.white),),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isCurrentUser = message.senderId == FirebaseAuth.instance.currentUser?.uid;

                return Align(
                  alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? primaryColor.withOpacity(0.9) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15).copyWith(
                        bottomRight: isCurrentUser ? Radius.zero : Radius.circular(15),
                        bottomLeft: isCurrentUser ? Radius.circular(15) : Radius.zero,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrentUser ? 'You' : _chatUserName ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCurrentUser ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: isCurrentUser ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      fillColor: Colors.grey[200],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: primaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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

class Message {
  final String senderId;
  final String text;
  final int timestamp;

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  Message.fromMap(Map<dynamic, dynamic> data)
      : senderId = data['senderId'] as String,
        text = data['text'] as String,
        timestamp = data['timestamp'] as int;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
    };
  }
}
