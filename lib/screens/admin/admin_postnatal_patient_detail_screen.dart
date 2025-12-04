import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';

class AdminPostnatalPatientDetailScreen extends StatefulWidget {
  final Map<String, String> patientData;
  final String initialView; // 'personal' or 'history'

  const AdminPostnatalPatientDetailScreen({
    super.key,
    required this.patientData,
    this.initialView = 'personal',
  });

  @override
  State<AdminPostnatalPatientDetailScreen> createState() =>
      _AdminPostnatalPatientDetailScreenState();
}

class _AdminPostnatalPatientDetailScreenState
    extends State<AdminPostnatalPatientDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  DateTime? _dob;
  int? _computedAge;
  DateTime? _deliveryDate;
  String? _deliveryPlace;
  String? _deliveryType;
  String? _infantName;
  String? _infantGender;
  String? _infantAge;
  String? _birthWeight;
  late String _activeView; // 'personal' or 'history'

  @override
  void initState() {
    super.initState();
    _activeView = widget.initialView;
    _fetchPatientData();
  }

  Future<void> _fetchPatientData() async {
    try {
      final String? userId = widget.patientData['patientId'];

      // Fetch appointments for this patient
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> appointments = [];
      for (var doc in appointmentsSnapshot.docs) {
        Map<String, dynamic> appointment = doc.data();
        appointment['id'] = doc.id;
        appointments.add(appointment);
      }

      // Fetch user profile for personal details
      if (userId != null && userId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          _userData = data;

          if (data['dob'] is Timestamp) {
            _dob = (data['dob'] as Timestamp).toDate();
          }

          final now = DateTime.now();
          if (_dob != null) {
            int age = now.year - _dob!.year;
            final birthdayThisYear = DateTime(now.year, _dob!.month, _dob!.day);
            if (now.isBefore(birthdayThisYear)) {
              age -= 1;
            }
            _computedAge = age;
          }

          if (data['dateOfDelivery'] is Timestamp) {
            _deliveryDate = (data['dateOfDelivery'] as Timestamp).toDate();
          } else if (data['deliveryDate'] is Timestamp) {
            _deliveryDate = (data['deliveryDate'] as Timestamp).toDate();
          }
          _deliveryPlace = data['placeOfDelivery']?.toString();
          _deliveryType = data['deliveryType']?.toString();
          _infantName = data['infantName']?.toString();
          _infantGender = data['infantGender']?.toString();
          _infantAge = data['infantAge']?.toString();
          _birthWeight = data['birthWeight']?.toString();
        }
      }

      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching patient data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditPersonalDetailsDialog() async {
    final String? userId = widget.patientData['patientId'];
    if (userId == null || userId.isEmpty) return;

    final data = _userData ?? {};

    final TextEditingController nameController = TextEditingController(
      text: (data['name'] ?? widget.patientData['name'] ?? '').toString(),
    );
    final TextEditingController emailController = TextEditingController(
      text: (data['email'] ?? widget.patientData['email'] ?? '').toString(),
    );
    final TextEditingController contactController = TextEditingController(
      text: (data['contactNumber'] ?? '').toString(),
    );

    final TextEditingController houseNoController = TextEditingController(
      text: (data['addressHouseNo'] ?? '').toString(),
    );
    final TextEditingController streetController = TextEditingController(
      text: (data['addressStreet'] ?? '').toString(),
    );
    final TextEditingController barangayController = TextEditingController(
      text: (data['addressBarangay'] ?? '').toString(),
    );
    final TextEditingController cityController = TextEditingController(
      text: (data['addressCity'] ?? '').toString(),
    );

    final TextEditingController emergencyNameController = TextEditingController(
      text: (data['emergencyContactName'] ?? '').toString(),
    );
    final TextEditingController emergencyContactController =
        TextEditingController(
      text: (data['emergencyContactNumber'] ?? '').toString(),
    );

    DateTime? editDob = _dob;
    String? civilStatus = (data['civilStatus'] ?? '').toString().isNotEmpty
        ? data['civilStatus'].toString()
        : null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Edit Personal Details',
                style: TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contactController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Date of Birth',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final now = DateTime.now();
                          final initial = editDob ??
                              DateTime(now.year - 25, now.month, now.day);
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(now.year - 100),
                            lastDate: now,
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              editDob = picked;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Text(
                            editDob == null
                                ? 'Select date of birth'
                                : '${editDob!.month.toString().padLeft(2, '0')}/${editDob!.day.toString().padLeft(2, '0')}/${editDob!.year}',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Regular',
                              color: editDob == null
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Complete Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: houseNoController,
                        decoration: const InputDecoration(
                          labelText: 'House No.',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: streetController,
                        decoration: const InputDecoration(
                          labelText: 'Street',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: barangayController,
                        decoration: const InputDecoration(
                          labelText: 'Barangay',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Civil Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: civilStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Single',
                            child: Text('Single'),
                          ),
                          DropdownMenuItem(
                            value: 'Married',
                            child: Text('Married'),
                          ),
                          DropdownMenuItem(
                            value: 'Widowed',
                            child: Text('Widowed'),
                          ),
                          DropdownMenuItem(
                            value: 'Separated',
                            child: Text('Separated'),
                          ),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            civilStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emergencyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emergencyContactController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontFamily: 'Regular',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        emailController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please provide at least name and email',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    try {
                      final Map<String, dynamic> update = {
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'contactNumber': contactController.text.trim(),
                        'addressHouseNo': houseNoController.text.trim(),
                        'addressStreet': streetController.text.trim(),
                        'addressBarangay': barangayController.text.trim(),
                        'addressCity': cityController.text.trim(),
                        'emergencyContactName':
                            emergencyNameController.text.trim(),
                        'emergencyContactNumber':
                            emergencyContactController.text.trim(),
                      };

                      if (civilStatus != null &&
                          civilStatus!.trim().isNotEmpty) {
                        update['civilStatus'] = civilStatus;
                      }
                      if (editDob != null) {
                        update['dob'] = Timestamp.fromDate(editDob!);
                      }

                      await _firestore
                          .collection('users')
                          .doc(userId)
                          .update(update);

                      if (!mounted) return;
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Personal details updated successfully',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      await _fetchPatientData();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to update personal details',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Bold',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),

          // Main Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back, size: 28),
                              color: Colors.black87,
                              tooltip: 'Back to Records',
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Patient Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Bold',
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // View Toggle
                        Row(
                          children: [
                            _buildViewToggleButton(
                                'Personal Details', 'personal'),
                            const SizedBox(width: 10),
                            _buildViewToggleButton(
                                'History Checkup', 'history'),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_activeView == 'personal') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _openEditPersonalDetailsDialog,
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(fontFamily: 'Medium'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildBasicInformationSection(),
                          const SizedBox(height: 20),
                          _buildRequiredProfileSection(),
                          const SizedBox(height: 20),
                          _buildDeliveryAndInfantSection(),
                        ] else ...[
                          _buildObstetricHistoryCard(),
                          const SizedBox(height: 30),
                          _buildCheckupHistoryTable(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          // User Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Bold',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Menu Items
          _buildMenuItem('DATA GRAPHS', false),
          _buildMenuItem('PRENATAL PATIENT\nRECORD', false),
          _buildMenuItem('POSTNATAL PATIENT\nRECORD', true),
          _buildMenuItem('APPOINTMENT\nSCHEDULING', false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!isActive) {
            Navigator.pop(context);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isActive ? Colors.white : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: isActive ? 'Bold' : 'Medium',
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(String label, String view) {
    final bool isSelected = _activeView == view;
    return TextButton(
      onPressed: isSelected
          ? null
          : () {
              setState(() {
                _activeView = view;
              });
            },
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? primary : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'Medium',
        ),
      ),
    );
  }

  Widget _buildBasicInformationSection() {
    final String name =
        (_userData?['name'] ?? widget.patientData['name'] ?? 'N/A').toString();
    final String email =
        (_userData?['email'] ?? widget.patientData['email'] ?? 'N/A')
            .toString();
    final String contact = (_userData?['contactNumber'] ?? 'N/A').toString();

    String dobText = 'N/A';
    if (_dob != null) {
      dobText =
          '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}';
    }

    final String ageText = _computedAge != null ? '$_computedAge' : 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Full Name:', name),
          _buildInfoRow('Age (years):', ageText),
          _buildInfoRow('Date of Birth:', dobText),
          _buildInfoRow('Email Address:', email),
          _buildInfoRow('Contact Number:', contact),
        ],
      ),
    );
  }

  Widget _buildRequiredProfileSection() {
    final String addressHouseNo =
        (_userData?['addressHouseNo'] ?? 'N/A').toString();
    final String addressStreet =
        (_userData?['addressStreet'] ?? 'N/A').toString();
    final String addressBarangay =
        (_userData?['addressBarangay'] ?? 'N/A').toString();
    final String addressCity = (_userData?['addressCity'] ?? 'N/A').toString();
    final String civilStatus = (_userData?['civilStatus'] ?? 'N/A').toString();
    final String emergencyName =
        (_userData?['emergencyContactName'] ?? 'N/A').toString();
    final String emergencyNumber =
        (_userData?['emergencyContactNumber'] ?? 'N/A').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required Profile Information (for booking appointments)',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Complete Address',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('House No.:', addressHouseNo),
          _buildInfoRow('Street:', addressStreet),
          _buildInfoRow('Barangay:', addressBarangay),
          _buildInfoRow('City:', addressCity),
          const SizedBox(height: 10),
          _buildInfoRow('Civil Status:', civilStatus),
          const SizedBox(height: 10),
          const Text(
            'Emergency Contact',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          _buildInfoRow('Name:', emergencyName),
          _buildInfoRow('Contact Number:', emergencyNumber),
        ],
      ),
    );
  }

  Widget _buildDeliveryAndInfantSection() {
    String deliveryDateText = 'N/A';
    if (_deliveryDate != null) {
      deliveryDateText =
          '${_deliveryDate!.month.toString().padLeft(2, '0')}/${_deliveryDate!.day.toString().padLeft(2, '0')}/${_deliveryDate!.year}';
    }

    final String place = _deliveryPlace ?? 'N/A';
    final String type = _deliveryType ?? 'N/A';
    final String infantName = _infantName ?? 'N/A';
    final String infantGender = _infantGender ?? 'N/A';
    final String infantAge = _infantAge ?? 'N/A';
    final String birthWeight = _birthWeight ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery & Infant Details',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Delivery Date:', deliveryDateText),
          _buildInfoRow('Place of Delivery:', place),
          _buildInfoRow('Type of Delivery:', type),
          const SizedBox(height: 10),
          _buildInfoRow("Infant's Name:", infantName),
          _buildInfoRow("Infant's Gender:", infantGender),
          _buildInfoRow('Birth Weight (kg):', birthWeight),
          _buildInfoRow("Infant's Age (months):", infantAge),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PATIENT INFORMATION',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          if (widget.patientData['patientId'] != null &&
              widget.patientData['patientId']!.isNotEmpty)
            _buildInfoRow('Patient ID:', widget.patientData['patientId']!),
          if (widget.patientData['name'] != null &&
              widget.patientData['name']!.isNotEmpty)
            _buildInfoRow('Name:', widget.patientData['name']!),
          if (widget.patientData['email'] != null &&
              widget.patientData['email']!.isNotEmpty)
            _buildInfoRow('Email:', widget.patientData['email']!),
          const SizedBox(height: 10),
          Text(
            'Additional patient information will be added during medical consultations.',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Regular',
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObstetricHistoryCard() {
    int totalAppointments = _appointments.length;
    int pendingCount =
        _appointments.where((a) => a['status'] == 'Pending').length;
    int acceptedCount =
        _appointments.where((a) => a['status'] == 'Accepted').length;
    int completedCount =
        _appointments.where((a) => a['status'] == 'Completed').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPLETED APPOINTMENT SUMMARY',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Total Appointments:', totalAppointments.toString()),
          _buildInfoRow('Pending:', pendingCount.toString()),
          _buildInfoRow('Accepted:', acceptedCount.toString()),
          _buildInfoRow('Completed:', completedCount.toString()),
          const SizedBox(height: 10),
          if (totalAppointments == 0)
            Text(
              'No appointments yet',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Regular',
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryCard() {
    // Get latest appointment if exists
    String latestAppointment = 'No appointments';
    String nextAppointment = 'No upcoming appointments';

    if (_appointments.isNotEmpty) {
      var latest = _appointments.first;
      latestAppointment = _formatDate(latest['createdAt']);

      // Find next accepted appointment
      var upcoming =
          _appointments.where((a) => a['status'] == 'Accepted').toList();
      if (upcoming.isNotEmpty) {
        nextAppointment =
            '${upcoming.first['day']} - ${upcoming.first['timeSlot']}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APPOINTMENT SCHEDULE',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Latest Appointment:', latestAppointment),
          const SizedBox(height: 5),
          _buildInfoRow('Next Scheduled:', nextAppointment),
          const SizedBox(height: 10),
          Text(
            'Patient Type: POSTNATAL',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Bold',
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaboratoryResultsCard() {
    int cancelledCount =
        _appointments.where((a) => a['status'] == 'Cancelled').length;
    String accountStatus = 'Active';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT STATUS',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accountStatus == 'Active' ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  accountStatus.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Bold',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Email:', widget.patientData['email'] ?? 'N/A'),
          const SizedBox(height: 5),
          _buildInfoRow('Cancelled Appointments:', cancelledCount.toString()),
          const SizedBox(height: 10),
          Text(
            'All appointment history is shown below',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Regular',
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckupHistoryTable() {
    if (_appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_note_outlined,
                  size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              const Text(
                'No Appointment Records',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Appointment records will appear here after the patient books appointments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Regular',
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
            child: const Text(
              'APPOINTMENT HISTORY',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color: Colors.black,
              ),
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('No.', flex: 1),
                _buildTableHeaderCell('Date', flex: 2),
                _buildTableHeaderCell('Day', flex: 2),
                _buildTableHeaderCell('Time Slot', flex: 2),
                _buildTableHeaderCell('Status', flex: 2),
                _buildTableHeaderCell('Patient Type', flex: 2),
              ],
            ),
          ),

          // Table Rows
          ..._appointments.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> appointment = entry.value;
            return Column(
              children: [
                _buildAppointmentRow(
                  (index + 1).toString(),
                  _formatDate(appointment['createdAt']),
                  appointment['appointmentDate'] != null
                      ? _formatDate(appointment['appointmentDate'])
                      : appointment['day'] ?? 'N/A',
                  appointment['timeSlot'] ?? 'N/A',
                  appointment['status'] ?? 'Pending',
                  appointment['patientType'] ?? 'POSTNATAL',
                  appointment,
                ),
                if (appointment['status'] == 'Accepted' ||
                    appointment['status'] == 'Completed')
                  _buildDetailedAppointmentView(appointment),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date = (timestamp as Timestamp).toDate();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildTableHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'Bold',
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAppointmentRow(
    String no,
    String date,
    String day,
    String timeSlot,
    String status,
    String patientType,
    Map<String, dynamic> appointment,
  ) {
    Color statusColor;
    if (status == 'Pending') {
      statusColor = Colors.orange;
    } else if (status == 'Accepted') {
      statusColor = Colors.green;
    } else if (status == 'Completed') {
      statusColor = Colors.blue;
    } else if (status == 'Cancelled') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _buildTableCell(no, flex: 1),
          _buildTableCell(date, flex: 2),
          _buildTableCell(day, flex: 2),
          _buildTableCell(timeSlot, flex: 2),
          Expanded(
            flex: 2,
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Bold',
                color: statusColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _buildTableCell(patientType, flex: 2),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'Regular',
          color: Colors.grey.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDetailedAppointmentView(Map<String, dynamic> appointment) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment Details',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),

          // Basic Information
          _buildDetailRow('Full Name:', appointment['fullName'] ?? 'N/A'),
          _buildDetailRow(
              'Appointment Type:', appointment['appointmentType'] ?? 'N/A'),
          _buildDetailRow(
              'Delivery Date:',
              appointment['deliveryDate'] != null
                  ? _formatDate(appointment['deliveryDate'])
                  : 'N/A'),
          _buildDetailRow(
              'Delivery Type:', appointment['deliveryType'] ?? 'N/A'),

          const SizedBox(height: 10),
          const Text(
            'Infant Information:',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          _buildDetailRow('Infant Name:', appointment['infantName'] ?? 'N/A'),
          _buildDetailRow(
              'Infant Gender:', appointment['infantGender'] ?? 'N/A'),
          _buildDetailRow('Infant Age:', appointment['infantAge'] ?? 'N/A'),

          const SizedBox(height: 10),
          const Text(
            'Health Assessment:',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          _buildDetailRow('Incision Concern:',
              appointment['incisionConcern'] == true ? 'Yes' : 'No'),
          _buildDetailRow('Heavy Bleeding:',
              appointment['heavyBleeding'] == true ? 'Yes' : 'No'),
          _buildDetailRow(
              'Depressed:', appointment['depressed'] == true ? 'Yes' : 'No'),
          _buildDetailRow(
              'No Pleasure:', appointment['noPleasure'] == true ? 'Yes' : 'No'),

          const SizedBox(height: 10),
          const Text(
            'Infant Feeding:',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          _buildDetailRow(
              'Feeding Method:', appointment['feedingMethod'] ?? 'N/A'),
          _buildDetailRow('Feeding Concern:',
              appointment['feedingConcern'] == true ? 'Yes' : 'No'),
          _buildDetailRow('Infant Fever:',
              appointment['infantFever'] == true ? 'Yes' : 'No'),
          _buildDetailRow(
              'Few Diapers:', appointment['fewDiapers'] == true ? 'Yes' : 'No'),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                    'Current Weight:', '${appointment['weight'] ?? 'N/A'} kg'),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildDetailRow('Blood Pressure:',
                    '${appointment['bloodPressure'] ?? 'N/A'} mmHg'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
