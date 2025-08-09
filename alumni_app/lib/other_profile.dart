import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'chat_screen.dart'; // Ensure you import your ChatScreen

class OtherProfileScreen extends StatefulWidget {
  final String userId; // The user ID to display

  const OtherProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _OtherProfileScreenState createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  final double coverHeight = 80;
  final double profileHeight = 130;

  final DatabaseReference _database = FirebaseDatabase.instance.reference().child('users');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _profileImage;
  bool _isLoading = false;
  String? _successMessage;

  String _selectedSection = 'profile';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final imageUrl = await _getCurrentProfilePictureUrl();
    if (imageUrl != null) {
      setState(() {
        _profileImage = File(imageUrl);
      });
    }
  }

  Future<String?> _getCurrentProfilePictureUrl() async {
    final profileImageSnapshot = await _database.child(widget.userId).child('profileImage').once();
    final imageUrl = profileImageSnapshot.snapshot.value as String?;
    return imageUrl?.isNotEmpty == true ? imageUrl : null;
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final userSnapshot = await _database.child(widget.userId).get();
    if (!userSnapshot.exists) return null;

    return {
      'name': userSnapshot.child('name').value,
      'email': userSnapshot.child('email').value,
      'profileImage': userSnapshot.child('profileImage').value,
      'batch': userSnapshot.child('batch').value,
      'department': userSnapshot.child('department').value,
      'job': userSnapshot.child('job').value,
      'job_title': userSnapshot.child('job_title').value,
      'working_place': userSnapshot.child('working_place').value,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xff5B75F0),
        iconTheme: IconThemeData(color:Colors.white),

        actions: [
          IconButton(
            icon: Icon(Icons.message, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChatScreen(chatUserId: widget.userId), // Pass userId here
                ),
              );
            }
              ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>( // Fetch user data
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color:Color(0xff5B75F0)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading data'));
          }

          final userData = snapshot.data;
          final profileImage = userData?['profileImage'] as String?;

          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              buildTop(profileImage),
              buildContent(userData),
              buildIconSection(), // Icon section

              if (_selectedSection == 'profile') ...[
                buildAdditionalDetails(userData),
              ] else if (_selectedSection == 'posts') ...[
                buildPosts(), // Display posts section
              ],
            ],
          );
        },
      ),
    );
  }

  Widget buildCoverImage() => Container(
    color: Colors.white,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff5B75F0), Color(0xff5B75F0)],
          stops: [0.2, 0.8],
        ),
      ),
    ),
    width: double.infinity,
    height: coverHeight,
  );

  Widget buildProfileImage(String? imageUrl) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      CircleAvatar(
        radius: profileHeight / 2,
        backgroundColor: Colors.grey.shade800,
        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
            ? NetworkImage(imageUrl)
            : AssetImage('assets/images/profileavatar.png') as ImageProvider,
      ),
    ],
  );

  Widget buildTop(String? profileImage) {
    final top = coverHeight - profileHeight / 2;
    final bottom = profileHeight / 2;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: bottom),
          child: buildCoverImage(),
        ),
        Positioned(
          top: top,
          child: buildProfileImage(profileImage),
        ),
      ],
    );
  }

  Widget buildContent(Map<String, dynamic>? userData) {
    final name = userData?['name'] ?? '-';

    return Column(
      children: [
        SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget buildAdditionalDetails(Map<String, dynamic>? userData) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.batch_prediction, color: Colors.black),
            title: Text('Batch: ${userData?['batch'] ?? 'Not available'}'),
          ),
          ListTile(
            leading: Icon(Icons.business, color: Colors.black),
            title: Text('Department: ${userData?['department'] ?? 'Not available'}'),
          ),
          ListTile(
            leading: Icon(Icons.work, color: Colors.black),
            title: Text('Job Status: ${userData?['job'] ?? 'Not available'}'),
          ),
          ListTile(
            leading: Icon(Icons.title, color: Colors.black),
            title: Text('Job Title: ${userData?['job_title'] ?? 'Not available'}'),
          ),
          ListTile(
            leading: Icon(Icons.location_on, color: Colors.black),
            title: Text('Working Place: ${userData?['working_place'] ?? 'Not available'}'),
          ),
        ],
      ),
    );
  }

  Widget buildPosts() {
    return Center(
      child: Text("Posts will be displayed here", style: TextStyle(fontSize: 18)),
    );
  }

  Widget buildIconSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.person, color: Color(0xff5B75F0), size: 25),
                  onPressed: () {
                    setState(() {
                      _selectedSection = 'profile'; // Set selected section to profile
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.post_add, color: Color(0xff5B75F0), size: 25),
                  onPressed: () {
                    setState(() {
                      _selectedSection = 'posts'; // Set selected section to posts
                    });
                  },
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}
