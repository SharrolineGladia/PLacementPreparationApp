import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<String> _chatUserIds = [];
  Map<String, String> _userNames = {};
  Map<String, String?> _profileImages = {};

  final Color primaryColor = const Color(0xff5B75F0);

  @override
  void initState() {
    super.initState();
    _loadChatUserIds();
  }

  Future<void> _loadChatUserIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final chatRef = _database.child('chats/$userId');
      chatRef.onValue.listen((DatabaseEvent event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          setState(() {
            _chatUserIds = data.keys.map((key) => key.toString()).toList();
          });
          _fetchUserDetails();
        }
      });
    }
  }

  Future<void> _fetchUserDetails() async {
    for (String chatUserId in _chatUserIds) {
      final userSnapshot = await _database.child('users/$chatUserId').once();
      if (userSnapshot.snapshot.value != null) {
        final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userNames[chatUserId] = userData['name'] as String? ?? 'Unknown';
          _profileImages[chatUserId] = userData['profileImage'] as String?;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text('Chats', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: _chatUserIds.isEmpty
          ? Center(
        child: Text(
          'No chats available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 18,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _chatUserIds.length,
        itemBuilder: (context, index) {
          final chatUserId = _chatUserIds[index];

          return ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: _profileImages[chatUserId] != null
                  ? NetworkImage(_profileImages[chatUserId]!)
                  : const AssetImage('assets/images/profileavatar.png')
              as ImageProvider,
              backgroundColor: Colors.grey[300],
            ),
            title: Text(
              _userNames[chatUserId] ?? 'Loading...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: primaryColor,
              size: 18,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChatScreen(chatUserId: chatUserId),
                ),
              );
            },
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          );
        },
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      ),
      backgroundColor: Colors.grey[100],
    );
  }
}
