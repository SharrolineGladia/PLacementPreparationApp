import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CumulativeProgressPage extends StatefulWidget {
  @override
  _CumulativeProgressPageState createState() => _CumulativeProgressPageState();
}

class _CumulativeProgressPageState extends State<CumulativeProgressPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.reference().child('interviewResults');
  List<Map<String, dynamic>> sessionsData = [];
  String currentMetric = 'overall';
  bool isLoading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  Future<void> getCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
      fetchData();
    } else {
      setState(() {
        isLoading = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('No user logged in. Please log in and try again.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  Future<void> fetchData() async {
    if (userId == null) return;

    try {
      final DataSnapshot snapshot = await dbRef.child(userId!).get();

      if (snapshot.value != null) {
        if (snapshot.value is Map) {
          final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          processMapData(values);
        } else {
          print('Unexpected data type: ${snapshot.value.runtimeType}');
        }
        sessionsData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        print(sessionsData); // Debug print
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void processMapData(Map<dynamic, dynamic> values) {
    values.forEach((sessionId, sessionData) {
      if (sessionData['summary'] != null) {
        sessionsData.add(createSessionDataMap(sessionId.toString(), sessionData));
      }
    });
  }

  Map<String, dynamic> createSessionDataMap(String sessionId, dynamic sessionData) {
    return {
      'sessionId': sessionId,
      'timestamp': sessionData['summary']['timestamp'] ?? 0,
      'averageOverallScore': sessionData['summary']['average_overall_score'] ?? 0.0,
      'averageClarity': calculateAverageScore(sessionData, 'clarity'),
      'averageRelevance': calculateAverageScore(sessionData, 'relevance'),
      'averageCorrectness': calculateAverageScore(sessionData, 'correctness'),
      'averageDepth': calculateAverageScore(sessionData, 'depth'),
      'questions': sessionData['questions'],
    };
  }

  double calculateAverageScore(dynamic sessionData, String metric) {
    if (sessionData['questions'] == null) return 0.0;

    double sum = 0.0;
    int count = 0;

    if (sessionData['questions'] is List) {
      for (var question in sessionData['questions']) {
        if (question['scores'] != null && question['scores'][metric] != null) {
          sum += (question['scores'][metric] as num).toDouble();
          count++;
        }
      }
    }

    return count > 0 ? sum / count : 0.0;
  }

  Widget buildGraph() {
    return Container(
      height: 300,
      padding: EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sessionsData.length) {
                    final date = DateTime.fromMillisecondsSinceEpoch(sessionsData[index]['timestamp']);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                interval: 1,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          minX: 0,
          maxX: sessionsData.length - 1.0,
          minY: 0,
          maxY: 11,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(sessionsData.length, (index) {
                double value;
                switch (currentMetric) {
                  case 'overall':
                    value = (sessionsData[index]['averageOverallScore'] as num).toDouble();
                    break;
                  case 'clarity':
                    value = (sessionsData[index]['averageClarity'] as num).toDouble();
                    break;
                  case 'relevance':
                    value = (sessionsData[index]['averageRelevance'] as num).toDouble();
                    break;
                  case 'correctness':
                    value = (sessionsData[index]['averageCorrectness'] as num).toDouble();
                    break;
                  case 'depth':
                    value = (sessionsData[index]['averageDepth'] as num).toDouble();
                    break;
                  default:
                    value = 0.0;
                }
                return FlSpot(index.toDouble(), value);
              }),
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(
                show: true,
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  final date = DateTime.fromMillisecondsSinceEpoch(sessionsData[flSpot.x.toInt()]['timestamp']);
                  return LineTooltipItem(
                    '${DateFormat('dd/MM/yyyy').format(date)}\n${currentMetric.capitalize()}: ${flSpot.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  Widget buildSessionsList() {
    return Expanded(
      child: ListView.builder(
        itemCount: sessionsData.length,
        itemBuilder: (context, index) {
          final session = sessionsData[index];
          final date = DateTime.fromMillisecondsSinceEpoch(session['timestamp']);
          return ExpansionTile(
            title: Text('Session ${index + 1} - ${DateFormat('dd/MM/yyyy').format(date)}'),
            subtitle: Text('Overall Score: ${session['averageOverallScore'].toStringAsFixed(2)}'),
            children: [
              if (session['questions'] != null)
                ...(session['questions'] as List<dynamic>).map((questionData) {
                  return ListTile(
                    title: Text('Question: ${questionData['question']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Feedback: ${questionData['feedback']}'),
                        Text('Scores:'),
                        Text('  Clarity: ${questionData['scores']['clarity']}'),
                        Text('  Relevance: ${questionData['scores']['relevance']}'),
                        Text('  Correctness: ${questionData['scores']['correctness']}'),
                        Text('  Depth: ${questionData['scores']['depth']}'),
                      ],
                    ),
                  );
                }).toList(),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cumulative Progress'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: currentMetric,
              items: <String>['overall', 'clarity', 'relevance', 'correctness', 'depth']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.capitalize()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    currentMetric = newValue;
                  });
                }
              },
            ),
          ),
          sessionsData.isEmpty
              ? Center(child: Text('No data available'))
              : buildGraph(),
          buildSessionsList(),
        ],
      ),
    );
  }
}

class CustomTooltip extends StatelessWidget {
  final String date;
  final String metric;
  final String value;

  const CustomTooltip({
    Key? key,
    required this.date,
    required this.metric,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session: $date', style: TextStyle(color: Colors.white, fontSize: 12)),
          Text('$metric: $value', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}