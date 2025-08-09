import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DatabaseReference userRef = FirebaseDatabase.instance.ref('users');
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  List<UserProfile> allUsers = [];
  List<UserProfile> filteredUsers = [];

  // Selected filters
  String selectedDepartment = 'All';
  String selectedYear = 'All';
  String selectedJobStatus = 'All';
  String selectedJobTitle = 'All';
  String selectedWorkingPlace = 'All';
  String searchQuery = '';

  // For dropdown items
  List<String> departments = ['All'];
  List<String> years = ['All'];
  List<String> jobStatuses = ['All', 'employed', 'unemployed'];
  List<String> jobTitles = ['All'];
  List<String> workingPlaces = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final snapshot = await userRef.once();
    if (snapshot.snapshot.value != null) {
      final usersMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
      allUsers = usersMap.entries.map((entry) {
        final userData = entry.value;
        final userName = userData['name'] ?? '';
        if (userName.toLowerCase() != 'admin') {
          return UserProfile(
            id: entry.key,
            name: userName,
            department: userData['department'] ?? '',
            batch: userData['batch'] ?? '',
            jobStatus: userData['job'] ?? '',
            jobTitle: userData['job_title'] ?? '',
            workingPlace: userData['working_place'] ?? '',
          );
        }
      }).where((user) => user != null).cast<UserProfile>().toList();
      _extractUniqueValues();
      _filterUsers();
    }
  }

  void _extractUniqueValues() {
    Set<String> departmentSet = {};
    Set<String> yearSet = {};
    Set<String> jobTitleSet = {};
    Set<String> workingPlaceSet = {};

    for (var user in allUsers) {
      departmentSet.add(user.department);
      yearSet.add(user.batch);
      jobTitleSet.add(user.jobTitle);
      workingPlaceSet.add(user.workingPlace);
    }

    setState(() {
      departments = ['All', ...departmentSet.toList()..removeWhere((item) => item.isEmpty)];
      years = ['All', ...yearSet.toList()..removeWhere((item) => item.isEmpty)];
      jobTitles = ['All', ...jobTitleSet.toList()..removeWhere((item) => item.isEmpty)];
      workingPlaces = ['All', ...workingPlaceSet.toList()..removeWhere((item) => item.isEmpty)];
    });
  }

  void _filterUsers() {
    setState(() {
      filteredUsers = allUsers.where((user) {
        final matchesSearch = user.name.toLowerCase().contains(searchQuery.toLowerCase());
        final matchesDepartment = selectedDepartment == 'All' || user.department == selectedDepartment;
        final matchesYear = selectedYear == 'All' || user.batch == selectedYear;
        final matchesJobStatus = selectedJobStatus == 'All' || user.jobStatus == selectedJobStatus;
        final matchesJobTitle = selectedJobTitle == 'All' || user.jobTitle == selectedJobTitle;
        final matchesWorkingPlace = selectedWorkingPlace == 'All' || user.workingPlace == selectedWorkingPlace;

        return matchesSearch && matchesDepartment && matchesYear &&
            matchesJobStatus && matchesJobTitle && matchesWorkingPlace;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _filterUsers();
                });
              },
            ),
          ),
          // Filters
          _buildFilters(),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text('${user.department} - ${user.batch}'),
                  onTap: () {
                    // Navigate to the user's profile or their own profile
                    if (user.id == currentUserId) {
                      Navigator.of(context).pushNamed('/profilescreen'); // Navigate to own profile
                    } else {
                      Navigator.of(context).pushNamed('/otherprofile', arguments: user.id); // Navigate to other profile
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          _buildDropdown(
            value: selectedDepartment,
            items: departments,
            onChanged: (value) {
              setState(() {
                selectedDepartment = value!;
                _filterUsers();
              });
            },
          ),
          const SizedBox(width: 8.0),
          _buildDropdown(
            value: selectedYear,
            items: years,
            onChanged: (value) {
              setState(() {
                selectedYear = value!;
                _filterUsers();
              });
            },
          ),
          const SizedBox(width: 8.0),
          _buildDropdown(
            value: selectedJobStatus,
            items: jobStatuses,
            onChanged: (value) {
              setState(() {
                selectedJobStatus = value!;
                _filterUsers();
              });
            },
          ),
          const SizedBox(width: 8.0),
          _buildDropdown(
            value: selectedJobTitle,
            items: jobTitles,
            onChanged: (value) {
              setState(() {
                selectedJobTitle = value!;
                _filterUsers();
              });
            },
          ),
          const SizedBox(width: 8.0),
          _buildDropdown(
            value: selectedWorkingPlace,
            items: workingPlaces,
            onChanged: (value) {
              setState(() {
                selectedWorkingPlace = value!;
                _filterUsers();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: DropdownButton<String>(
        isExpanded: true,
        value: items.contains(value) ? value : null, // Ensure the value is valid
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String department;
  final String batch;
  final String jobStatus;
  final String jobTitle;
  final String workingPlace;

  UserProfile({
    required this.id,
    required this.name,
    required this.department,
    required this.batch,
    required this.jobStatus,
    required this.jobTitle,
    required this.workingPlace,
  });
}