import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Database package
import 'Firebasedbquestions.dart'; // Import the questions file

class AdminPage extends StatelessWidget {
  final DatabaseReference _questionsRef = FirebaseDatabase.instance.ref('questions'); // Reference to the 'questions' node

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Page'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Delete all content in the 'questions' node
              await _questionsRef.remove();

              // Call the addQuestions function to add new questions
              await addQuestions();

              // Show a confirmation message after adding questions
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Questions deleted and added successfully!')),
              );
            } catch (e) {
              // Show an error message if there's an issue
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update questions: $e')),
              );
            }
          },
          child: Text('Add Questions'),
        ),
      ),
    );
  }
}
