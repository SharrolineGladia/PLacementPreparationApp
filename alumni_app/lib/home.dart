import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'PostCreationPage.dart';
import 'other_profile.dart'; // Import the OtherProfile page

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _selectedPostType = 'All';
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPosts = {};
  // Purple from the image

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }
  void _fetchPosts() {
    DatabaseReference postsRef = FirebaseDatabase.instance.ref().child('posts');
    String userId = FirebaseAuth.instance.currentUser!.uid;

    postsRef.onValue.listen((event) async {
      dynamic dataSnapshot = event.snapshot.value;
      if (dataSnapshot != null && dataSnapshot is Map) {
        List<Map<String, dynamic>> tempPosts = [];
        List<Future<Map<String, dynamic>?>> futures = [];

        for (var entry in dataSnapshot.entries) {
          String key = entry.key;
          var value = entry.value;

          String author = value['author'] ?? 'Unknown Author';
          String authorId = value['userId'] ?? ''; // Get the userId
          String text = value['text'] ?? 'No text available';
          String mediaUrl = value['mediaURL'] ?? '';
          String postType = value['postType'] ?? 'Unknown';
          String description = value['description'] ?? '';
          String webinarLink = value['webinarLink'] ?? '';
          int likes = (value['likes'] is int) ? value['likes'] : 0;
          Map likedBy = value['likedBy'] ?? {};
          Map comments = value['comments'] ?? {};

          if (likedBy.containsKey(userId)) {
            _likedPosts.add(key);
          }

          if (_selectedPostType == 'All' || _selectedPostType == postType) {
            futures.add(_getProfileImage(authorId).then((profileImageUrl) {
              return {
                'key': key,
                'author': author,
                'authorId': authorId, // Pass authorId to the post
                'timestamp': value['timestamp'] ?? 0,
                'text': text,
                'mediaURL': mediaUrl,
                'postType': postType,
                'description': description,
                'webinarLink': webinarLink,
                'profileImageUrl': profileImageUrl,
                'likes': likes,
                'comments': comments,
              };
            }));
          }
        }

        List<Map<String, dynamic>?> results = await Future.wait(futures);
        tempPosts = results.where((post) => post != null).cast<Map<String, dynamic>>().toList();

        setState(() {
          _posts = tempPosts;
        });
      } else {
        print('No posts data available');
        setState(() {
          _posts = [];
        });
      }
    }, onError: (Object error) {
      print('Error fetching posts: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch posts')),
      );
    });
  }

  Future<String> _getProfileImage(String userId) async {
    DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users').child(userId);
    try {
      DataSnapshot snapshot = await userRef.get();
      if (snapshot.exists && snapshot.value is Map) {
        // Ensure the 'profileImage' field is correctly retrieved
        String imageUrl = (snapshot.value as Map)['profileImage'] ?? 'https://via.placeholder.com/150';

        // Check if the imageUrl is not empty
        if (imageUrl.isNotEmpty) {
          return imageUrl;
        }
      }
      return 'https://via.placeholder.com/150'; // Fallback placeholder
    } catch (e) {
      print('Error fetching profile image: $e');
      return 'https://via.placeholder.com/150'; // Fallback placeholder
    }
  }



  void _likePost(String postId) {
    DatabaseReference postRef = FirebaseDatabase.instance.ref().child('posts').child(postId);

    postRef.runTransaction((currentData) {
      if (currentData != null && currentData is Map) {
        Map<dynamic, dynamic> post = currentData as Map<dynamic, dynamic>;

        List<dynamic> likedUsers = post['likedUsers'] != null ? List<dynamic>.from(post['likedUsers']) : [];

        if (likedUsers.contains(FirebaseAuth.instance.currentUser!.uid)) {
          post['likes'] = (post['likes'] ?? 0) > 0 ? (post['likes'] - 1) : 0;
          likedUsers.remove(FirebaseAuth.instance.currentUser!.uid);
          _likedPosts.remove(postId);
        } else {
          post['likes'] = (post['likes'] ?? 0) + 1;
          likedUsers.add(FirebaseAuth.instance.currentUser!.uid);
          _likedPosts.add(postId);
        }

        post['likedUsers'] = likedUsers;

        return Transaction.success(post);
      } else {
        return Transaction.abort();
      }
    }).then((result) {
      if (result.committed) {
        setState(() {
          // Update UI based on the new like state
        });
      }
    }).catchError((error) {
      print('Error updating like count: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like/unlike the post')),
      );
    });
  }

  void _addComment(String postId, String commentText) async {
    DatabaseReference postRef = FirebaseDatabase.instance.ref().child('posts').child(postId).child('comments');
    String userId = FirebaseAuth.instance.currentUser!.uid;
    String commentId = postRef.push().key!;

    Map<String, dynamic> commentData = {
      'author': userId,
      'text': commentText,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };

    await postRef.child(commentId).set(commentData);
  }

  void _launchWebinarLink(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showCommentDialog(String postId) {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Comment'),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(hintText: 'Enter your comment'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                _addComment(postId, commentController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _onItemTapped(int index) {
    switch (index) {
      case 0: // Home
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1: // Search
        Navigator.pushNamed(context, '/search');
        break;
      case 2: // Post
        Navigator.pushNamed(context, '/postcreationpage');
        break;
      case 3: // Messages
        Navigator.pushNamed(context, '/mockinterview');
        break;
      case 4: // Profile
        Navigator.pushNamed(context, '/profilescreen');
        break;
      default:
        break;
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(

        title: Center(child: Text('Home',style: TextStyle(color: Colors.white),)),
        backgroundColor: Color(0xff5B75F0),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.message, color: Colors.white),
            onPressed: () async {
              Navigator.pushNamed(context,'/chatlistscreen');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xff5B75F0),
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Resume Upload'),
              onTap: () async {
                Navigator.pushNamed(context,'/resumeupload');
              },
            ),
            ListTile(
              leading: Icon(Icons.check),
              title: Text('Check Progress'),
              onTap: () async {
                Navigator.pushNamed(context,'/checkprogress');
              },
            ),
          ],
        ),
      ),
      body:
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: _selectedPostType,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPostType = newValue ?? 'All';
                  _fetchPosts();
                });
              },
              items: <String>['All', 'Interview Tips', 'Industry Advice', 'Preparation Strategies']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _posts.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final mediaUrl = post['mediaURL'] ?? '';
                final isVideo = mediaUrl.contains('.mp4');
                final isLiked = _likedPosts.contains(post['key']);

                return PostCard(
                  post: post,
                  isVideo: isVideo,
                  onLike: () => _likePost(post['key']),
                  onComment: () => _showCommentDialog(post['key']),
                  launchWebinar: () {
                    if (post['webinarLink'] != null && post['webinarLink'].isNotEmpty) {
                      _launchWebinarLink(post['webinarLink']);
                    }
                  },
                  isLiked: isLiked,
                  onAuthorTap: () {
                    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
                    if (post['authorId'] == currentUserId) {
                      Navigator.pushNamed(context, '/profilescreen');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherProfileScreen(userId: post['authorId']),
                        ),
                      );
                    }
                  },

                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xff5B75F0), // Set the background color to your purple
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outlined), label: 'Mock Interview'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white,  // Change selected item color to black
        unselectedItemColor: Colors.white, // Unselected item color also black for consistency
        iconSize: 30.0, // Adjust icon size to 30 for better alignment
        type: BottomNavigationBarType.fixed, // Ensure fixed type for consistency across screen sizes
      ),


    );
  }
}

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isVideo;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback launchWebinar;
  final bool isLiked;
  final VoidCallback onAuthorTap;

  PostCard({
    required this.post,
    required this.isVideo,
    required this.onLike,
    required this.onComment,
    required this.launchWebinar,
    required this.isLiked,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      margin: EdgeInsets.all(8.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // Same corner radius as Container
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(post['profileImageUrl']),
              ),
              title: GestureDetector(
                onTap: onAuthorTap,
                child: Text(post['author']),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['postType'],
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black),
                  ),
                  SizedBox(height: 4.0),
                  Text(post['text']),
                  SizedBox(height: 4.0),
                  if (post['description'].isNotEmpty)
                    Text(post['description']),
                  SizedBox(height: 4.0),
                  if (post['webinarLink'].isNotEmpty)
                    GestureDetector(
                      onTap: launchWebinar,
                      child: Text(
                        post['webinarLink'],
                        style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      ),
                    ),
                ],
              ),
            ),
            if (isVideo)
              VideoPlayerWidget(videoUrl: post['mediaURL'])
            else if (post['mediaURL'].isNotEmpty)
              Image.network(post['mediaURL']),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.black,
                      ),
                      onPressed: onLike,
                    ),
                    Text('${post['likes']} Likes'),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.comment),
                  onPressed: onComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ... [VideoPlayerWidget remains unchanged]
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  VideoPlayerWidget({required this.videoUrl});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    )
        : Container();
  }
}