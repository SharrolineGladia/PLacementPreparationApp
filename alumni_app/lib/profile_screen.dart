import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseReference postsRef = FirebaseDatabase.instance.ref().child('posts');
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final double coverHeight = 80;
  final double profileHeight = 130;

  final DatabaseReference _database = FirebaseDatabase.instance.reference().child('users');
  final DatabaseReference _postsDatabase = FirebaseDatabase.instance.reference().child('posts'); // Added for posts
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _profileImage;
  bool _isLoading = false;
  String? _successMessage;

  String _selectedSection = 'profile';
  List<dynamic> _posts = []; // Added for storing posts

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _fetchPosts(); // Fetch posts on init
  }

  Future<void> _loadProfileImage() async {
    final imageUrl = await _getCurrentProfilePictureUrl();
    if (imageUrl != null) {
      setState(() {
        _profileImage = File(imageUrl); // Update this line if you need to fetch image from network
      });
    }
  }

  Future<String?> _getCurrentProfilePictureUrl() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final profileImageSnapshot = await _database.child(user.uid).child('profileImage').once();
    final imageUrl = profileImageSnapshot.snapshot.value as String?;

    return imageUrl?.isNotEmpty == true ? imageUrl : null;
  }

  Future<void> _fetchPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postsSnapshot = await _postsDatabase.orderByChild('userId').equalTo(user.uid).once();
    if (postsSnapshot.snapshot.exists) {
      setState(() {
        final postsMap = postsSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        _posts = postsMap?.values.map((post) {
          if (post is Map<dynamic, dynamic>) {
            return post; // Return post if valid Map
          }
          return null; // Return null for invalid posts
        }).where((post) => post != null).toList() ?? []; // Filter out null posts
      });
    } else {
      setState(() {
        _posts = []; // Set to empty list if no posts exist
      });
    }
  }



  Future<void> _deleteOldProfilePicture(String oldImageUrl) async {
    final oldImageRef = _storage.refFromURL(oldImageUrl);
    try {
      await oldImageRef.delete();
    } catch (e) {
      print("Error deleting old profile picture: $e");
    }
  }

  Future<void> _updateProfilePicture(File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentImageUrl = await _getCurrentProfilePictureUrl();
    if (currentImageUrl != null) {
      await _deleteOldProfilePicture(currentImageUrl);
    }

    final storageRef = _storage.ref().child('profile_pictures').child(user.uid + '.jpg');

    try {
      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();

      await _database.child(user.uid).child('profileImage').set(imageUrl);

      setState(() {
        _profileImage = imageFile; // Update profile image after upload
        _successMessage = 'Profile picture updated successfully!';
      });
    } catch (e) {
      setState(() {
        _successMessage = 'Failed to update profile picture.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteProfilePicture() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentImageUrl = await _getCurrentProfilePictureUrl();
    if (currentImageUrl != null) {
      try {
        final storageRef = _storage.refFromURL(currentImageUrl);
        await storageRef.delete();
        await _database.child(user.uid).child('profileImage').remove();

        setState(() {
          _profileImage = null; // Update profile image to null after deletion
          _successMessage = 'Profile picture deleted successfully!';
        });
      } catch (e) {
        setState(() {
          _successMessage = 'Failed to delete profile picture.';
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _updateProfilePicture(imageFile);
    }
  }

  Future<void> _showImageOptions() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose an action'),
        actions: <Widget>[
          TextButton(
            child: Text('Take Photo', style: TextStyle(color: Color(0xff3A3C4B)),),
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          TextButton(
            child: Text('Pick from Gallery', style: TextStyle(color: Color(0xff3A3C4B)),),
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          if (_profileImage != null) // Show this only if there is a profile image
            TextButton(
              child: Text('Delete Photo', style: TextStyle(color: Color(0xff3A3C4B)),),
              onPressed: () {
                Navigator.pop(context);
                _deleteProfilePicture();
              },
            ),
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Color(0xff3A3C4B)),),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    final userSnapshot = await _database.child(user.uid).get();
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
  Future<void> _deleteUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _database.child(user.uid).remove(); // Remove user data from the database
      await user.delete(); // Delete user from Firebase Authentication
      Navigator.pop(context); // Navigate back after deletion
    } catch (e) {
      print('Error deleting user: $e');
    }
  }
  Future<void> _showDeleteConfirmation() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete your profile? This action cannot be undone.'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(); // Delete the user profile
            },
          ),
        ],
      ),
    );
  }
  Widget buildPosts() {
    return FutureBuilder<DataSnapshot>(
      future: postsRef.orderByChild('userId').equalTo(currentUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.value as Map<dynamic, dynamic>?;

        if (posts == null || posts.isEmpty) {
          return Center(child: Text('No posts available.'));
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postKey = posts.keys.elementAt(index);
            final post = posts[postKey];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        post['mediaURL'] ?? 'https://via.placeholder.com/150',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${post['likes']}',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 3.0,
                                color: Colors.white,
                                offset: Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: IconThemeData(color:Colors.white),
        backgroundColor: Color(0xff5B75F0),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Color(0xff5B75F0)),
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

              // Conditionally render based on selected section
              if (_selectedSection == 'profile') ...[
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(color: Color(0xff5B75F0)),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(_successMessage!, style: TextStyle(color: Colors.green)),
                    ),
                  ),
                buildAdditionalDetails(userData),
                buildProfileButtons(),
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
          colors: [Color(0xff5B75F0),Color(0xff5B75F0)],
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
      Positioned(
        bottom: 0,
        right: -10,
        child: buildEditIcon(Color(0xff5B75F0)),
      ),
    ],
  );


  Widget buildEditIcon(Color color) => buildCircle(
    color: Colors.white,
    all: 2,
    child: buildCircle(
      color: color,
      all: 5,
      child: IconButton(
        icon: Icon(Icons.edit, color: Colors.white, size: 17),
        onPressed: _showImageOptions,
      ),
    ),
  );


  Widget buildCircle({
    required Widget child,
    required double all,
    required Color color,
  }) => ClipOval(
    child: Container(
      padding: EdgeInsets.all(all),
      color: color,
      child: child,
    ),
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
        )
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
  Widget buildProfileButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff5B75F0),
            ),
            onPressed: () async {
              // Navigate to EditProfileScreen and wait for result
              final result = await Navigator.pushNamed(context, '/editprofile');

              // Check if the result indicates that changes were made
              if (result == true) {
                // Refresh the profile data by calling setState
                setState(() {});
              }
            },
            child: Text('Edit Profile', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: _showDeleteConfirmation,
            child: Text('Delete Profile', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // Modified buildIconSection method
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
