import 'package:alumni_app/CumulativeProgress.dart';
import 'package:alumni_app/adminpage.dart';
import 'package:alumni_app/chat_screen.dart';
import 'package:alumni_app/editprofile.dart';
import 'package:alumni_app/home.dart';
import 'package:alumni_app/mockinterview.dart';
import 'package:alumni_app/profile_screen.dart';
import 'package:alumni_app/other_profile.dart'; // Import the other profile screen
import 'package:alumni_app/search.dart';
import 'package:alumni_app/signup_screen.dart';
import 'package:alumni_app/login_screen.dart';
import 'package:alumni_app/PostCreationPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'chatlistscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alumni Connection App',
      routes: {
        '/': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/postcreationpage': (context) => AddPostScreen(),
        '/profilescreen': (context) => ProfileScreen(),
        '/editprofile': (context) => EditProfileScreen(),
        '/adminpage' : (context) => AdminPage(),
        '/mockinterview' : (context) => InterviewScreen(),
        // Update the routing for OtherProfileScreen
        '/otherprofile': (context) {
          final String userId = ModalRoute.of(context)!.settings.arguments as String;
          return OtherProfileScreen(userId: userId);
        },
        '/chatlistscreen' : (context) => ChatListScreen(),
        '/checkprogress' : (context) => CumulativeProgressPage(),
        '/search' : (context) => SearchScreen(),
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xff5B75F0)),
        useMaterial3: true,
      ),
    );
  }
}
