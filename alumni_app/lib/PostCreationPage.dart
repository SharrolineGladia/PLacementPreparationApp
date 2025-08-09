import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddPostScreen extends StatefulWidget {
  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _webinarLinkController = TextEditingController();
  final _database = FirebaseDatabase.instance.ref().child('posts');
  File? _mediaFile;
  String? _selectedPostType; // Initially null
  String? _userName = FirebaseAuth.instance.currentUser?.displayName;

  // Method to pick media file (image/video) from gallery
  Future<void> _pickMedia() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
      });
    } else {
      print('No media file picked');
    }
  }

  // Method to upload file to Firebase Storage
  Future<String?> _uploadFile(File file) async {
    try {
      String fileName = 'posts/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      UploadTask uploadTask = FirebaseStorage.instance.ref(fileName).putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Method to submit post
  void _submitPost() async {
    String postText = _postController.text.trim();
    String description = _descriptionController.text.trim();
    String webinarLink = _webinarLinkController.text.trim();

    if (postText.isNotEmpty && description.isNotEmpty && _mediaFile != null) {
      String? mediaURL = await _uploadFile(_mediaFile!);

      if (mediaURL != null) {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            Map<String, dynamic> postData = {
              'author': _userName ?? 'Anonymous',
              'userId': user.uid, // Add userId to post data
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'text': postText,
              'description': description,
              'postType': _selectedPostType,
              'mediaURL': mediaURL,
            };

            // If the post type is 'Webinar', include the webinar link in the data
            if (_selectedPostType == 'Webinar' && webinarLink.isNotEmpty) {
              postData['webinarLink'] = webinarLink;
            }

            await _database.push().set(postData);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Post added successfully')));
            Navigator.pop(context); // Navigate back after posting
          } catch (e) {
            print('Error adding post: $e');
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Failed to add post')));
          }
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('User not authenticated')));
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload media')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill in all fields and select media')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Post',
          style: TextStyle(color: Colors.white), // Set text color to white
        ),
        centerTitle: true,
        backgroundColor: Color(0xff5B75F0), // Updated AppBar color
        iconTheme: IconThemeData(color: Colors.white), // Set icon color to white if needed
      ),
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black), // Black outline
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 5,
                blurRadius: 7,
                offset: Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          margin: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _postController,
                  decoration: InputDecoration(
                    labelText: 'Post Text',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: TextStyle(color: Colors.black), // Text color
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                  style: TextStyle(color: Colors.black), // Text color
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPostType,
                  decoration: InputDecoration(
                    labelText: 'Post Type',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedPostType = newValue;
                    });
                  },
                  items: <String>['Interview Tips', 'Industry Advice', 'Preparation Strategies']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: Colors.black)), // Text color
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Show Webinar link input only if 'Webinar' is selected
                if (_selectedPostType == 'Webinar')
                  TextField(
                    controller: _webinarLinkController,
                    decoration: InputDecoration(
                      labelText: 'Webinar Link',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black), // Text color
                  ),

                SizedBox(height: 16),
                if (_mediaFile != null)
                  Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      image: DecorationImage(
                        image: FileImage(_mediaFile!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Text('No media selected', style: TextStyle(color: Colors.black)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickMedia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff5B75F0), // Updated button color
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Pick Media', style: TextStyle(fontSize: 16, color: Colors.white)), // Updated text color
                ),
                SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff5B75F0), // Updated button color
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    ),
                    child: Text('Submit Post', style: TextStyle(fontSize: 18, color: Colors.white)), // Updated text color
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}