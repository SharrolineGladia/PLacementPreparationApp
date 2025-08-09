import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class InterviewScreen extends StatefulWidget {
  @override
  _InterviewScreenState createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  static const String baseUrl = 'http://192.168.66.15:5000';

  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  TextEditingController answerController = TextEditingController();
  bool interviewComplete = false;
  bool isLoading = false;
  bool isRecording = false;
  bool isPlaying = false;
  final audioPlayer = AudioPlayer();
  late FlutterSoundRecorder soundRecorder;
  String? recordingPath;
  List<double> overallScores = [];
  double averageOverallScore = 0;
  late DateTime recordingStartTime;
  late DatabaseReference dbRef;
  late String sessionId;
  String? userId;

  @override
  void initState() {
    super.initState();
    soundRecorder = FlutterSoundRecorder();
    initRecorder();
    initFirebase();
    startInterview();
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      dbRef = FirebaseDatabase.instance.reference().child('interviewResults').child(userId!);
      sessionId = Uuid().v4(); // Generate a unique session ID
    } else {
      // Handle the case where no user is logged in
      showErrorDialog('No user logged in. Please log in and try again.');
    }
  }

  Future<void> initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await soundRecorder.openRecorder();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    soundRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> toggleRecording() async {
    if (isRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  Future<void> startInterview() async {
    setState(() {
      isLoading = true;
    });
    DateTime interviewStartTime = DateTime.now();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/start_interview'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10)); // 10-second timeout

      print(response.body);

      if (response.statusCode == 200) {
        DateTime questionFetchTime = DateTime.now();
        print('Time taken to fetch questions: ${questionFetchTime.difference(interviewStartTime).inMilliseconds} ms');
        final data = json.decode(response.body);
        print(data);

        setState(() {
          questions = List<Map<String, dynamic>>.from(data['questions']);
          isLoading = false;
        });
        playQuestion();
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      showErrorDialog('Connection timed out. Please check your internet connection and try again.');
    } on SocketException catch (e) {
      showErrorDialog('Network error: ${e.message}. Please check your connection and server availability.');
    } catch (e) {
      showErrorDialog('Failed to start interview: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> playQuestion() async {
    setState(() {
      isLoading = true;
    });

    DateTime audioStartTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_question_audio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'question': questions[currentQuestionIndex]['question']}),
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final tempPath = tempDir.path;
        final filePath = '$tempPath/question_audio.mp3';
        await File(filePath).writeAsBytes(bytes);

        await audioPlayer.play(DeviceFileSource(filePath));
        setState(() {
          isLoading = false;
          isPlaying = true;
        });

        audioPlayer.onPlayerComplete.listen((event) {
          DateTime audioEndTime = DateTime.now(); // Log time when audio finishes
          print('Time taken to play audio: ${audioEndTime.difference(audioStartTime).inMilliseconds} ms');
          setState(() {
            isPlaying = false;
          });
        });
      } else {
        throw Exception('Failed to get question audio');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showErrorDialog('Failed to play question: $e');
    }
  }

  Future<void> startRecording() async {
    recordingStartTime = DateTime.now();
    try {
      final tempDir = await getTemporaryDirectory();
      recordingPath = '${tempDir.path}/answer.aac';
      await soundRecorder.startRecorder(
        toFile: recordingPath,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 44100,
      );
      setState(() {
        isRecording = true;
      });
    } catch (e) {
      showErrorDialog('Failed to start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    DateTime recordingEndTime = DateTime.now();
    try {
      await soundRecorder.stopRecorder();
      setState(() {
        isRecording = false;
      });

      print('Time taken for recording: ${recordingEndTime.difference(recordingStartTime).inMilliseconds} ms');
      if (recordingPath != null) {
        await submitAudioAnswer(recordingPath!);
      }
    } catch (e) {
      showErrorDialog('Failed to stop recording: $e');
    }
  }

  Future<void> submitAudioAnswer(String path) async {
    DateTime submitStartTime = DateTime.now();
    setState(() {
      isLoading = true;
    });
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/submit_audio_answer'));
      request.files.add(await http.MultipartFile.fromPath('file', path));
      request.fields['file_type'] = 'aac';
      request.headers['Content-Type'] = 'multipart/form-data';

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          answerController.text = data['transcription'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to submit audio answer');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showErrorDialog('Failed to submit audio answer: $e');
    }

    DateTime submitEndTime = DateTime.now(); // Log time when audio submission ends
    print('Time taken to submit audio answer: ${submitEndTime.difference(submitStartTime).inMilliseconds} ms');
  }

  Future<void> submitAnswer() async {
    if (answerController.text.isEmpty) {
      showErrorDialog('Please enter an answer before submitting.');
      return;
    }

    DateTime submitStartTime = DateTime.now();

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/evaluate_answer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'question': questions[currentQuestionIndex],
          'answer': answerController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        await storeResultInFirebase(data);

        setState(() {
          // Add the overall score for this question to our list
          overallScores.add(double.parse(data['overall_score'].toString()));

          // Calculate the average overall score
          averageOverallScore = overallScores.reduce((a, b) => a + b) / overallScores.length;

          if (currentQuestionIndex < questions.length - 1) {
            currentQuestionIndex++;
            answerController.clear();
            playQuestion();
          } else {
            interviewComplete = true;
            storeSessionSummary();
          }
          isLoading = false;
        });
      } else {
        throw Exception('Failed to evaluate answer');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showErrorDialog('Failed to evaluate answer: $e');
    }
    DateTime submitEndTime = DateTime.now(); // Log time when text submission ends
    print('Time taken to submit text answer: ${submitEndTime.difference(submitStartTime).inMilliseconds} ms');
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> storeResultInFirebase(Map<String, dynamic> data) async {
    if (userId == null) {
      showErrorDialog('No user logged in. Results cannot be stored.');
      return;
    }
    await dbRef.child(sessionId).child('questions').child(currentQuestionIndex.toString()).set({
      'question': questions[currentQuestionIndex]['question'],
      'answer': answerController.text,
      'feedback': {
        'relevance': data['relevance_feedback'],
        'correctness': data['correctness_feedback'],
        'clarity': data['clarity_feedback'],
        'depth': data['depth_feedback'],
      },
      'scores': {
        'relevance': data['relevance'],
        'correctness': data['correctness'],
        'clarity': data['clarity'],
        'depth': data['depth'],
        'overall': data['overall_score'],
      },
    });

    // Update the summary after each question
    await storeSessionSummary();
  }

  Future<void> storeSessionSummary() async {
    if (userId == null) {
      showErrorDialog('No user logged in. Summary cannot be stored.');
      return;
    }
    await dbRef.child(sessionId).child('summary').set({
      'average_overall_score': averageOverallScore,
      'total_questions': questions.length,
      'completed_questions': currentQuestionIndex + 1,
      'completed_at': ServerValue.timestamp,
      'scores_per_question': overallScores,
      'timestamp': ServerValue.timestamp, // Add this line to store the timestamp
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mock Interview'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (!interviewComplete) ...[
            // Question display area
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      questions.isNotEmpty ? questions[currentQuestionIndex]['question'] : 'Loading...',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: isPlaying ? null : playQuestion,
                    tooltip: 'Play Question',
                  ),
                ],
              ),
            ),

            // Bot image
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/botavatar1.webp',
                  width: 400,
                  height: 400,
                ),
              ),
            ),

            // Answer text field
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: answerController,
                decoration: InputDecoration(
                  labelText: 'Your Answer',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ),

            // Record and submit buttons
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: toggleRecording,
                    child: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      size: 40,
                      color: isRecording ? Colors.red : Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      backgroundColor: isRecording ? Colors.white : Theme.of(context).primaryColor,
                      padding: EdgeInsets.all(20),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: submitAnswer,
                    child: Icon(Icons.check, size: 40),
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(20),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Interview Complete!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Average Overall Score: ${averageOverallScore.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scores per question:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ...List.generate(overallScores.length, (index) {
                      return Text(
                        'Question ${index + 1}: ${overallScores[index].toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 16),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}