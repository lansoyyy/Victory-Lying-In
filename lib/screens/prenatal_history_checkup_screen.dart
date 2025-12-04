import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';
import '../widgets/forgot_password_dialog.dart';
import 'prenatal_dashboard_screen.dart';
import 'notification_appointment_screen.dart';
import 'transfer_record_request_screen.dart';
import 'auth/home_screen.dart';

class PrenatalHistoryCheckupScreen extends StatefulWidget {
  const PrenatalHistoryCheckupScreen({super.key});

  @override
  State<PrenatalHistoryCheckupScreen> createState() =>
      _PrenatalHistoryCheckupScreenState();
}

class _PrenatalHistoryCheckupScreenState
    extends State<PrenatalHistoryCheckupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = 'Loading...';
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _completedAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadUserData();
    _loadCompletedAppointments();
  }

  Future<void> _loadUserName() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userName = userData['name'] ?? 'User';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'User';
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && mounted) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadCompletedAppointments() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot appointmentSnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .where('status', whereIn: ['Completed', 'Rescheduled']).get();

        List<Map<String, dynamic>> appointments = [];
        for (var doc in appointmentSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          appointments.add(data);
        }

        // Sort in memory by createdAt
        appointments.sort((a, b) {
          var aTime = a['createdAt'];
          var bTime = b['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return (aTime as Timestamp).compareTo(bTime as Timestamp);
        });

        if (mounted) {
          setState(() {
            _completedAppointments = appointments;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error loading appointments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title
                  const Text(
                    'Prenatal Checkup History',
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: 'Bold',
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'View your completed prenatal appointments and checkup records',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Patient Information Card
                  _buildPatientInfoCard(),
                  const SizedBox(height: 30),

                  // All Completed Appointments Summary
                  if (_completedAppointments.isNotEmpty) ...[
                    const Text(
                      'Completed Appointments Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Bold',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ..._completedAppointments.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> appointment = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildAppointmentSummaryCard(
                            appointment, index + 1),
                      );
                    }).toList(),
                    const SizedBox(height: 30),
                  ],

                  // Checkup History Table
                  const Text(
                    'Appointment History',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Bold',
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildCheckupHistoryTable(),
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
                  _userName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Bold',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'PRENATAL PATIENT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Regular',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Menu Items (kept consistent with main dashboard)
          _buildMenuItem('PERSONAL DETAILS', false),
          _buildMenuItem('EDUCATIONAL\nLEARNERS', false),
          _buildMenuItem('HISTORY OF\nCHECK UP', true),
          _buildMenuItem('REQUEST &\nNOTIFICATION APPOINTMENT', false),
          _buildMenuItem('TRANSFER OF\nRECORD REQUEST', false),

          _buildMenuItem('CHANGE PASSWORD', false),
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
          if (title == 'CHANGE PASSWORD') {
            showDialog(
              context: context,
              builder: (context) => const ForgotPasswordDialog(),
            );
            return;
          }
          if (title == 'PERSONAL DETAILS') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const PrenatalDashboardScreen(
                  openPersonalDetailsOnLoad: true,
                ),
              ),
            );
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
      case 'EDUCATIONAL\nLEARNERS':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const PrenatalDashboardScreen()),
        );
        break;
      case 'HISTORY OF\nCHECK UP':
        // Already on this screen
        break;
      case 'REQUEST &\nNOTIFICATION APPOINTMENT':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const NotificationAppointmentScreen(patientType: 'PRENATAL')),
        );
        break;
      case 'TRANSFER OF\nRECORD REQUEST':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const TransferRecordRequestScreen(patientType: 'PRENATAL')),
        );
        break;
    }
  }

  Widget _buildPatientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.1), secondary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['name'] ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Bold',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _userData?['email'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _userData?['contact'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${_completedAppointments.length}',
                  style: TextStyle(
                    fontSize: 28,
                    fontFamily: 'Bold',
                    color: primary,
                  ),
                ),
                Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentSummaryCard(
      Map<String, dynamic> appointment, int visitNumber) {
    String completedDate = 'N/A';
    if (appointment['createdAt'] != null) {
      try {
        DateTime dateTime = (appointment['createdAt'] as Timestamp).toDate();
        completedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        completedDate = 'N/A';
      }
    }

    // Next visit date (used for recommendation display)
    String scheduleDate = 'N/A';
    DateTime? nextVisit;
    if (appointment['nextVisitDate'] is Timestamp) {
      try {
        nextVisit = (appointment['nextVisitDate'] as Timestamp).toDate();
      } catch (_) {}
    }

    if (nextVisit != null) {
      scheduleDate = '${nextVisit.day}/${nextVisit.month}/${nextVisit.year}';
    } else if (appointment['appointmentDate'] is Timestamp) {
      try {
        final DateTime schedDate =
            (appointment['appointmentDate'] as Timestamp).toDate();
        scheduleDate = '${schedDate.day}/${schedDate.month}/${schedDate.year}';
      } catch (_) {}
    } else if (appointment['day'] != null) {
      scheduleDate = appointment['day'].toString();
    }
    // timeSlot is no longer shown in the summary card

    // Findings and notes (prescription / recommendation)
    final String findingsText;
    final rawFindings = appointment['findings']?.toString();
    if (rawFindings != null && rawFindings.trim().isNotEmpty) {
      findingsText = rawFindings;
    } else {
      findingsText = 'No findings recorded';
    }

    String notesText = '';
    final rawNotes = appointment['notes']?.toString();
    if (rawNotes != null && rawNotes.trim().isNotEmpty) {
      notesText = rawNotes;
    } else {
      final advice = appointment['advice']?.toString();
      if (advice != null && advice.trim().isNotEmpty) {
        notesText = advice;
      }
    }
    if (notesText.isEmpty) {
      notesText = 'No prescription / recommendation';
    }

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$visitNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['appointmentType'] ?? 'Clinic',
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Bold',
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Completed on $completedDate',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: appointment['status'] == 'Rescheduled'
                      ? Colors.blue.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appointment['status'] ?? 'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: appointment['status'] == 'Rescheduled'
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details in 3 columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Next Visit Recommendation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Next Visit Recommendation',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Bold',
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Date:', scheduleDate),
                    if (appointment['rescheduledAt'] != null)
                      _buildInfoRow('Rescheduled on:',
                          _formatDate(appointment['rescheduledAt'])),
                  ],
                ),
              ),
              // Column 2: Reason
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_services, size: 16, color: primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Reason',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Bold',
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appointment['reason'] ?? 'Not specified',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Column 3: Findings and Notes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_alt, size: 16, color: primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Findings',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Bold',
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      findingsText,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Notes (Prescription / Recommendation)',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Bold',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notesText,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Remarks Laboratory Result',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Bold',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appointment['labRemarks']?.toString().trim().isNotEmpty ==
                              true
                          ? appointment['labRemarks'].toString()
                          : 'No laboratory remarks recorded',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  String _formatDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCheckupHistoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
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
                _buildTableHeaderCell('Visit No.', flex: 1),
                _buildTableHeaderCell('Date', flex: 2),
                _buildTableHeaderCell('Age of Gestation (weeks)', flex: 2),
                _buildTableHeaderCell('Weight (kg)', flex: 2),
                _buildTableHeaderCell('Blood Pressure (mmHg)', flex: 3),
                _buildTableHeaderCell('Fetal Heart Rate (bpm)', flex: 3),
                _buildTableHeaderCell('Fundal Height (cm)', flex: 3),
                _buildTableHeaderCell('Remarks / Observation', flex: 3),
                _buildTableHeaderCell('Risk Classification', flex: 3),
              ],
            ),
          ),

          // Table Rows - Dynamic from Firestore
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: primary),
              ),
            )
          else if (_completedAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No completed checkups yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ..._completedAppointments.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> appointment = entry.value;
              return _buildTableRowFromAppointment(
                (index + 1).toString(),
                appointment,
              );
            }).toList(),
        ],
      ),
    );
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

  Widget _buildTableRowFromAppointment(
      String visitNo, Map<String, dynamic> appointment) {
    String date = 'N/A';
    DateTime? dateTime;
    if (appointment['appointmentDate'] is Timestamp) {
      try {
        dateTime = (appointment['appointmentDate'] as Timestamp).toDate();
      } catch (_) {}
    } else if (appointment['createdAt'] is Timestamp) {
      try {
        dateTime = (appointment['createdAt'] as Timestamp).toDate();
      } catch (_) {}
    }
    if (dateTime != null) {
      date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    // Age of Gestation (weeks)
    String gaText = 'N/A';
    if (_userData != null && _userData!['lmpDate'] is Timestamp) {
      try {
        final DateTime lmp = (_userData!['lmpDate'] as Timestamp).toDate();
        DateTime referenceDate = dateTime ?? DateTime.now();
        final int days = referenceDate.difference(lmp).inDays;
        if (days >= 0) {
          final double weeks = days / 7.0;
          gaText = weeks.toStringAsFixed(1);
        }
      } catch (_) {}
    }

    String weightText = 'N/A';
    final weightValue = appointment['checkupWeightKg'];
    if (weightValue != null) {
      if (weightValue is num) {
        weightText = weightValue.toStringAsFixed(weightValue is int ? 0 : 1);
      } else {
        final parsed = double.tryParse(weightValue.toString());
        if (parsed != null) {
          weightText = parsed.toStringAsFixed(1);
        } else {
          weightText = weightValue.toString();
        }
      }
    }

    String bpText = '';
    final bpValue = appointment['checkupBloodPressure'];
    if (bpValue != null && bpValue.toString().trim().isNotEmpty) {
      bpText = bpValue.toString();
    } else {
      final sys = appointment['checkupBP_Systolic'];
      final dia = appointment['checkupBP_Diastolic'];
      if (sys != null && dia != null) {
        bpText = '${sys.toString()}/${dia.toString()}';
      }
    }
    if (bpText.isEmpty) {
      bpText = 'N/A';
    }

    String fhrText = 'N/A';
    final fhr = appointment['checkupFetalHeartRateBpm'];
    if (fhr != null) {
      fhrText = fhr.toString();
    }

    String fundalText = 'N/A';
    final fh = appointment['checkupFundalHeightCm'];
    if (fh != null) {
      if (fh is num) {
        fundalText = fh.toStringAsFixed(fh is int ? 0 : 1);
      } else {
        final parsed = double.tryParse(fh.toString());
        if (parsed != null) {
          fundalText = parsed.toStringAsFixed(1);
        } else {
          fundalText = fh.toString();
        }
      }
    }

    String remarksText =
        appointment['checkupRemarks']?.toString().trim().isNotEmpty == true
            ? appointment['checkupRemarks'].toString()
            : (appointment['notes']?.toString() ?? '-');

    String riskText =
        appointment['visitRiskStatus']?.toString().trim().isNotEmpty == true
            ? appointment['visitRiskStatus'].toString()
            : (appointment['riskStatus']?.toString() ?? 'N/A');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _buildTableCell(visitNo, flex: 1),
          _buildTableCell(date, flex: 2),
          _buildTableCell(gaText, flex: 2),
          _buildTableCell(weightText, flex: 2),
          _buildTableCell(bpText, flex: 3),
          _buildTableCell(fhrText, flex: 3),
          _buildTableCell(fundalText, flex: 3),
          _buildTableCell(remarksText, flex: 3),
          _buildTableCell(riskText, flex: 3),
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
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xffEC008C), fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );
  }
}
