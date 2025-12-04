import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maternity_clinic/screens/admin/admin_postnatal_patient_detail_screen.dart';
import 'package:maternity_clinic/screens/transfer_record_request_screen.dart';
import 'package:maternity_clinic/utils/colors.dart';

import 'admin_prenatal_records_screen.dart';
import 'admin_appointment_management_screen.dart';
import 'admin_appointment_scheduling_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_educational_cms_screen.dart';
import '../auth/home_screen.dart';

class AdminPostnatalRecordsScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const AdminPostnatalRecordsScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<AdminPostnatalRecordsScreen> createState() =>
      _AdminPostnatalRecordsScreenState();
}

class _AdminPostnatalRecordsScreenState
    extends State<AdminPostnatalRecordsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'ACTIVE';
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _searchController.addListener(_filterPatients);
  }

  Future<void> _fetchPatients() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('patientType', isEqualTo: 'POSTNATAL')
          .get();

      List<Map<String, dynamic>> patients = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Only include fields that have actual data
        Map<String, dynamic> patient = {
          'id': doc.id,
          'patientId': data['patientId'] ?? _generatePatientId(doc.id),
        };

        // Only add fields if they exist and are not empty
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          patient['name'] = data['name'];
        }
        if (data['email'] != null && data['email'].toString().isNotEmpty) {
          patient['email'] = data['email'];
        }
        if (data['age'] != null && data['age'].toString().isNotEmpty) {
          patient['age'] = data['age'].toString();
        }
        if (data['deliveryType'] != null &&
            data['deliveryType'].toString().isNotEmpty) {
          patient['deliveryType'] = data['deliveryType'];
        }
        if (data['dateOfDelivery'] != null &&
            data['dateOfDelivery'].toString().isNotEmpty) {
          patient['dateOfDelivery'] = data['dateOfDelivery'];
        }
        if (data['address'] != null && data['address'].toString().isNotEmpty) {
          patient['address'] = data['address'];
        }
        if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
          patient['contact'] = data['phone'];
        }
        if (data['contactNumber'] != null &&
            data['contactNumber'].toString().isNotEmpty) {
          patient['contact'] = data['contactNumber'];
        }

        // Account status and manual risk/specific complication (for staff updates)
        final rawAccountStatus = data['accountStatus']?.toString();
        final accountStatus =
            (rawAccountStatus == null || rawAccountStatus.isEmpty)
                ? 'Active'
                : rawAccountStatus;
        patient['accountStatus'] = accountStatus;
        patient['status'] = accountStatus;

        if (data['riskStatus'] != null &&
            data['riskStatus'].toString().isNotEmpty) {
          patient['riskStatus'] = data['riskStatus'];
        }
        if (data['specificComplication'] != null &&
            data['specificComplication'].toString().isNotEmpty) {
          patient['specificComplication'] = data['specificComplication'];
        }

        // Fetch latest appointment data
        final appointmentSnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: doc.id)
            .where('appointmentType', isEqualTo: 'Postnatal Checkup')
            .orderBy('appointmentDate', descending: true)
            .limit(1)
            .get();

        if (appointmentSnapshot.docs.isNotEmpty) {
          final appointmentData = appointmentSnapshot.docs.first.data();
          patient['latestAppointment'] = appointmentData;
          patient['latestAppointmentId'] = appointmentSnapshot.docs.first.id;
        }

        patients.add(patient);
      }

      if (mounted) {
        setState(() {
          _patients = patients;
          _filteredPatients = patients;
          _isLoading = false;
        });
        _filterPatients();
      }
    } catch (e) {
      print('Error fetching postnatal patients: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generatePatientId(String docId) {
    // Generate pattern: PNL 2 2025 - 0001 (2 for postnatal)
    final currentYear = DateTime.now().year;
    final hash = docId.hashCode.abs();
    final sequence = (hash % 9999) + 1;
    return 'PNL 2 $currentYear - ${sequence.toString().padLeft(4, '0')}';
  }

  String _calculatePostpartumPeriod(String deliveryDate) {
    try {
      final parts = deliveryDate.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final delivery = DateTime(year, month, day);
        final now = DateTime.now();
        final difference = now.difference(delivery);
        final days = difference.inDays;
        final weeks = days ~/ 7;
        final remainingDays = days % 7;

        if (weeks > 0) {
          return 'Postpartum Week $weeks, Day $remainingDays';
        } else {
          return 'Postpartum Day $days';
        }
      }
    } catch (e) {
      print('Error calculating postpartum period: $e');
    }
    return 'N/A';
  }

  String _assessPostnatalRiskStatus(Map<String, dynamic> patient) {
    // If staff/admin has manually set a risk status on the patient record,
    // always honor that as the primary risk level.
    final manualRisk = patient['riskStatus']?.toString();
    if (manualRisk != null && manualRisk.isNotEmpty) {
      return manualRisk;
    }

    final appointment = patient['latestAppointment'] as Map<String, dynamic>?;
    if (appointment == null) return 'LOW RISK';

    // Check HIGH RISK criteria
    bool highRisk = false;

    // Mother: Heavy Bleeding/Discharge
    if (appointment['heavyBleedingDischarge'] == 'YES') {
      highRisk = true;
    }

    // Mother: BP Concern (140/90 or higher)
    final bp = appointment['currentBloodPressure']?.toString() ?? '';
    if (bp.contains('/')) {
      final parts = bp.split('/');
      final systolic = int.tryParse(parts[0]) ?? 0;
      final diastolic = int.tryParse(parts[1]) ?? 0;
      if (systolic >= 140 || diastolic >= 90) {
        highRisk = true;
      }
    }

    // Infant: Fever
    if (appointment['infantFever'] == 'YES') {
      highRisk = true;
    }

    if (highRisk) return 'HIGH RISK';

    // Check CAUTION criteria (only if not already HIGH RISK)
    bool caution = false;

    // Mother: Mental Health(Depression)
    if (appointment['maternalMentalHealth'] == 'YES') {
      caution = true;
    }

    // Mother: Wound Concern
    if (appointment['maternalWoundConcern'] == 'YES') {
      caution = true;
    }

    // Infant: Feeding/Weight Concern
    if (appointment['infantFeedingWeightConcern'] == 'YES') {
      caution = true;
    }

    // Infant: Hydration
    if (appointment['infantHydration'] == 'YES') {
      caution = true;
    }

    if (caution) return 'CAUTION';

    return 'LOW RISK';
  }

  Color _getRiskColor(String riskStatus) {
    switch (riskStatus) {
      case 'HIGH RISK':
        return Colors.red;
      case 'CAUTION':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _rescheduleAppointment(
      String appointmentId, String patientName) async {
    // Implement reschedule dialog similar to admin appointment scheduling screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Reschedule feature for $patientName - To be implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _completeAppointment(
      String appointmentId, String patientName) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'Completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment for $patientName marked as completed'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchPatients(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showViewProfileDialog(Map<String, dynamic> patient,
      String mothersName, String patientId) async {
    final String userId = patient['id'] as String? ?? '';
    String status = patient['accountStatus']?.toString() ?? 'Active';
    String risk = patient['riskStatus']?.toString().isNotEmpty == true
        ? patient['riskStatus'].toString()
        : 'LOW RISK';
    String specificComplication =
        patient['specificComplication']?.toString() ?? '';

    final complications = <String>[
      'None',
      'GDM (Gestational Diabetes)',
      'Preeclampsia',
      'Eclampsia',
      'Placenta Previa',
      'Placental Abruption',
      'Multiple Pregnancy',
      'History of C-Section',
      'Other',
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'View Profile (Staff Editing Mode)',
            style: TextStyle(fontFamily: 'Bold'),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mothersName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patient ID: $patientId',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Status (Active / Inactive)',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Bold',
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      status = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Risk Level',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Bold',
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: risk,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'LOW RISK', child: Text('LOW RISK')),
                    DropdownMenuItem(value: 'CAUTION', child: Text('CAUTION')),
                    DropdownMenuItem(
                        value: 'HIGH RISK', child: Text('HIGH RISK')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      risk = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Specific Complication',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Bold',
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: specificComplication.isEmpty
                      ? 'None'
                      : specificComplication,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  items: complications
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      specificComplication = value == 'None' ? '' : value;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _firestore.collection('users').doc(userId).update({
                    'accountStatus': status,
                    'riskStatus': risk,
                    'specificComplication': specificComplication,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Profile updated successfully',
                          style: TextStyle(fontFamily: 'Regular'),
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  Navigator.pop(context);
                  await _fetchPatients();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Failed to update profile',
                          style: TextStyle(fontFamily: 'Regular'),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(fontFamily: 'Bold'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _getLastAppointmentDate(String patientId) async {
    try {
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .where('appointmentType', isEqualTo: 'Postnatal Checkup')
          .orderBy('appointmentDate', descending: true)
          .limit(1)
          .get();

      if (appointmentsSnapshot.docs.isNotEmpty) {
        final appointmentData = appointmentsSnapshot.docs.first.data();
        final timestamp = appointmentData['appointmentDate'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
        }
      }
      return 'No appointments';
    } catch (e) {
      print('Error fetching last appointment: $e');
      return 'Error';
    }
  }

  void _filterPatients() {
    String query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredPatients = _patients.where((patient) {
        final name = patient['name']?.toString().toLowerCase() ?? '';
        final patientId = patient['patientId']?.toString().toLowerCase() ?? '';
        final latestAppointmentId =
            patient['latestAppointmentId']?.toString().toLowerCase() ?? '';

        final bool matchesSearch = query.isEmpty ||
            name.contains(query) ||
            patientId.contains(query) ||
            latestAppointmentId.contains(query);

        return matchesSearch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search and Filter Row
                  Row(
                    children: [
                      // Search Field
                      Container(
                        width: 250,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'SEARCH NAME OR ID',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Regular',
                              color: Colors.grey.shade600,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Regular',
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Active Filter Button
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = 'ACTIVE';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedFilter == 'ACTIVE'
                              ? Colors.grey.shade300
                              : Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontFamily: 'Bold',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Table
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: primary))
                          : _filteredPatients.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No postnatal patients found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Regular',
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: _buildPatientTable(),
                                ),
                    ),
                  ),
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
              children: [
                Text(
                  widget.userName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Bold',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.userRole.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Medium',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Menu Items
          _buildMenuItem('DATA GRAPHS', false),
          _buildMenuItem('APPOINTMENT MANAGEMENT', false),
          _buildMenuItem('APPROVE SCHEDULES', false),
          _buildMenuItem('PATIENT RECORDS', true),
          _buildMenuItem('CONTENT MANAGEMENT', false),

          _buildMenuItem('LOGOUT', false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (title == 'LOGOUT') {
            _showLogoutConfirmationDialog();
            return;
          }
          if (!isActive) {
            _handleNavigation(title);
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

  void _handleNavigation(String title) {
    switch (title) {
      case 'DATA GRAPHS':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
      case 'APPOINTMENT MANAGEMENT':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminAppointmentManagementScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
      case 'APPROVE SCHEDULES':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminAppointmentSchedulingScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
      case 'CONTENT MANAGEMENT':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminEducationalCmsScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
    }
  }

  Widget _buildPatientTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: Row(
            children: [
              _buildHeaderCell('PATIENT ID', flex: 1),
              _buildHeaderCell("MOTHER'S NAME", flex: 2),
              _buildHeaderCell("INFANT'S NAME", flex: 2),
              _buildHeaderCell('APPOINTMENT DATE/TIME', flex: 2),
              _buildHeaderCell('POSTPARTUM PERIOD', flex: 2),
              _buildHeaderCell('DATE OF DELIVERY', flex: 2),
              _buildHeaderCell('DELIVERY TYPE', flex: 2),
              _buildHeaderCell("INFANT'S GENDER", flex: 1),
              _buildHeaderCell('FEEDING METHOD', flex: 2),
              _buildHeaderCell("MOTHER'S BP", flex: 1),
              _buildHeaderCell('RISK STATUS', flex: 2),
              _buildHeaderCell('APPOINTMENT STATUS', flex: 2),
              _buildHeaderCell('ACTIONS', flex: 2),
            ],
          ),
        ),

        // Table Rows
        ..._filteredPatients.map((patient) {
          return _buildTableRow(patient);
        }).toList(),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
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

  Widget _buildTableRow(Map<String, dynamic> patient) {
    String patientId = patient['patientId'] ?? 'N/A';
    String mothersName = patient['name'] ?? 'Unknown';

    final appointment = patient['latestAppointment'] as Map<String, dynamic>?;
    final appointmentId = patient['latestAppointmentId'] as String?;

    // Appointment details
    String appointmentDate = 'N/A';
    String timeSlot = 'N/A';
    String appointmentStatus = appointment?['status'] ?? 'No Appointment';
    String infantsName = appointment?['infantsName'] ?? 'N/A';
    String infantGender = appointment?['infantsGender'] ?? 'N/A';
    String feedingMethod = appointment?['infantFeedingMethod'] ?? 'N/A';
    String mothersBP = appointment?['currentBloodPressure'] ?? 'N/A';

    if (appointment != null && appointment['appointmentDate'] != null) {
      final timestamp = appointment['appointmentDate'] as Timestamp;
      final date = timestamp.toDate();
      appointmentDate =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
      timeSlot = appointment['timeSlot'] ?? 'N/A';
    }

    // Postpartum period calculation
    String postpartumPeriod = 'N/A';
    String deliveryDate = patient['dateOfDelivery'] ?? 'N/A';
    String deliveryType = patient['deliveryType'] ?? 'N/A';

    if (deliveryDate != 'N/A') {
      postpartumPeriod = _calculatePostpartumPeriod(deliveryDate);
    }

    // Risk assessment
    final riskStatus = _assessPostnatalRiskStatus(patient);
    final riskColor = _getRiskColor(riskStatus);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPostnatalPatientDetailScreen(
                patientData: patient
                    .map((key, value) => MapEntry(key, value.toString())),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              _buildTableCell(patientId, flex: 1),
              _buildTableCell(mothersName, flex: 2),
              _buildTableCell(infantsName, flex: 2),
              _buildTableCell('$appointmentDate\n$timeSlot', flex: 2),
              _buildTableCell(postpartumPeriod, flex: 2),
              _buildTableCell(deliveryDate, flex: 2),
              _buildTableCell(deliveryType, flex: 2),
              _buildTableCell(infantGender, flex: 1),
              _buildTableCell(feedingMethod, flex: 2),
              _buildTableCell(mothersBP, flex: 1),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: riskColor),
                    ),
                    child: Text(
                      riskStatus,
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'Bold',
                        color: riskColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(appointmentStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _getStatusColor(appointmentStatus)),
                    ),
                    child: Text(
                      appointmentStatus,
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'Bold',
                        color: _getStatusColor(appointmentStatus),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await _showViewProfileDialog(
                          patient,
                          mothersName,
                          patientId,
                        );
                      },
                      child: const Text(
                        'View Profile',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Bold',
                        ),
                      ),
                    ),
                    if (appointmentId != null &&
                        appointmentStatus == 'Accepted') ...[
                      IconButton(
                        icon: const Icon(Icons.schedule,
                            size: 14, color: Colors.orange),
                        onPressed: () =>
                            _rescheduleAppointment(appointmentId, mothersName),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle,
                            size: 14, color: Colors.green),
                        onPressed: () =>
                            _completeAppointment(appointmentId, mothersName),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.isNotEmpty ? text : '-',
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'Regular',
          color: text.isNotEmpty ? Colors.grey.shade700 : Colors.grey.shade400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Logout Confirmation',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontFamily: 'Regular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style:
                  TextStyle(color: Colors.grey.shade600, fontFamily: 'Medium'),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: Text(
              'Logout',
              style: TextStyle(color: Colors.red.shade600, fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );
  }
}
