import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _database = FirebaseDatabase.instance.reference().child('users');

  // Controllers for text fields
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _workingPlaceController = TextEditingController();

  // Dropdown values
  String? _selectedBatch;
  String? _selectedDepartment;
  String? _selectedJobStatus;

  // Lists for dropdown items
  final List<String> _batches = ['','2017','2018','2019','2020','2021', '2022', '2023', '2024'];
  final List<String> _departments = [
    '', 'CSE', 'IT', 'CSBS', 'Data Science', 'Mechanical', 'Civil', 'Mechatronics', 'AIML'
  ];
  final List<String> _jobStatuses = ['employed', 'unemployed'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnapshot = await _database.child(user.uid).get();
    if (!userSnapshot.exists) return;

    setState(() {
      _selectedBatch = userSnapshot.child('batch').value as String?;
      _selectedDepartment = userSnapshot.child('department').value as String?;
      _selectedJobStatus = userSnapshot.child('job').value as String?;
      _jobTitleController.text = userSnapshot.child('job_title').value as String? ?? '';
      _workingPlaceController.text = userSnapshot.child('working_place').value as String? ?? '';
    });
  }

  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _database.child(user.uid).update({
      'batch': _selectedBatch ?? '',
      'department': _selectedDepartment ?? '',
      'job': _selectedJobStatus ?? 'unemployed',
      'job_title': _jobTitleController.text,
      'working_place': _workingPlaceController.text,
    });

    // Return to previous screen with a result indicating profile update
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xff5B75F0),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildDropdown(
                label: 'Select Batch',
                value: _selectedBatch,
                items: _batches,
                onChanged: (value) => setState(() => _selectedBatch = value),
                validator: (value) => value == null || value.isEmpty ? 'Please select a batch' : null,
              ),
              SizedBox(height: 16),
              _buildDropdown(
                label: 'Select Department',
                value: _selectedDepartment,
                items: _departments,
                onChanged: (value) => setState(() => _selectedDepartment = value),
                validator: (value) => value == null || value.isEmpty ? 'Please select a department' : null,
              ),
              SizedBox(height: 16),
              _buildDropdown(
                label: 'Select Job Status',
                value: _selectedJobStatus,
                items: _jobStatuses,
                onChanged: (value) => setState(() => _selectedJobStatus = value),
                validator: (value) => value == null || value.isEmpty ? 'Please select a job status' : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                label: 'Job Title',
                controller: _jobTitleController,
                validator: (value) => value!.isEmpty ? 'Please enter your job title' : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                label: 'Working Place',
                controller: _workingPlaceController,
                validator: (value) => value!.isEmpty ? 'Please enter your working place' : null,
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildButton(
                    label: 'Submit',
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _updateProfile();
                      }
                    },
                  ),
                  _buildButton(
                    label: 'Cancel',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    color: Colors.red[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }

  Widget _buildButton({required String label, required VoidCallback onPressed, Color? color}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        backgroundColor: color ?? Color(0xff5B75F0), // Default color for Submit button
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(fontSize: 16, color: Colors.white), // Text color set to white
      ),
    );
  }

}
