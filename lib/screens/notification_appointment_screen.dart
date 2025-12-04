import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';
import '../widgets/forgot_password_dialog.dart';
import 'prenatal_dashboard_screen.dart';
import 'postnatal_dashboard_screen.dart';
import 'prenatal_history_checkup_screen.dart';
import 'postnatal_history_checkup_screen.dart';
import 'transfer_record_request_screen.dart';
import 'prenatal_update_profile_screen.dart';
import 'postnatal_update_profile_screen.dart';
import 'auth/home_screen.dart';
import '../widgets/book_appointment_dialog.dart';

class NotificationAppointmentScreen extends StatefulWidget {
  final String patientType; // 'PRENATAL' or 'POSTNATAL'

  const NotificationAppointmentScreen({
    super.key,
    required this.patientType,
  });

  @override
  State<NotificationAppointmentScreen> createState() =>
      _NotificationAppointmentScreenState();
}

class _NotificationAppointmentScreenState
    extends State<NotificationAppointmentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = 'Loading...';
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  bool _profileCompleted = false;
  int _selectedTabIndex = 0; // 0 = upcoming, 1 = history

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadUserAppointments();
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
              _profileCompleted = userData['profileCompleted'] == true;
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

  Future<void> _openRequestCheckup() async {
    if (!_profileCompleted) {
      _showProfileRequiredDialog();
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => BookAppointmentDialog(
        patientType: widget.patientType,
      ),
    );
  }

  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Update Profile Required',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: Text(
          widget.patientType == 'POSTNATAL'
              ? 'Before you can book an appointment you need to fill out "Update Profile" in your postnatal dashboard.'
              : 'Before you can book an appointment you need to fill out "Update Profile" in your prenatal dashboard.',
          style: const TextStyle(fontFamily: 'Regular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style:
                  TextStyle(color: Colors.grey.shade700, fontFamily: 'Medium'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final Widget target = widget.patientType == 'POSTNATAL'
                  ? const PostnatalUpdateProfileScreen()
                  : const PrenatalUpdateProfileScreen();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => target,
                ),
              ).then((_) {
                _loadUserName();
              });
            },
            child: Text(
              'Go to Update Profile',
              style: TextStyle(color: primary, fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserAppointments() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('Current User UID: ${user.uid}');

        // Query without orderBy to avoid index requirement
        QuerySnapshot appointmentSnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .get();

        print(
            'Appointments found for current user: ${appointmentSnapshot.docs.length}');

        List<Map<String, dynamic>> appointments = [];
        for (var doc in appointmentSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          appointments.add(data);
          print('Appointment: ${data['reason']} - Status: ${data['status']}');
        }

        // Sort in memory instead of in query
        appointments.sort((a, b) {
          var aTime = a['createdAt'];
          var bTime = b['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });

        if (mounted) {
          setState(() {
            _appointments = appointments;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading appointments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isUpcomingAppointment(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? 'Pending').toString();
    if (status == 'Completed' || status == 'Cancelled' || status == 'No-show') {
      return false;
    }

    // For POSTNATAL patients, do not show 'Pending' appointments as upcoming
    // so they only appear in the history tab.
    if (widget.patientType == 'POSTNATAL' && status == 'Pending') {
      return false;
    }

    if (appointment['appointmentDate'] is! Timestamp) {
      return false;
    }

    final DateTime date =
        (appointment['appointmentDate'] as Timestamp).toDate();
    return date.isAfter(DateTime.now());
  }

  bool _canCancelAppointment(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? 'Pending').toString();
    if (status != 'Pending') {
      return false;
    }
    if (appointment['appointmentDate'] is! Timestamp) {
      return false;
    }
    final DateTime date =
        (appointment['appointmentDate'] as Timestamp).toDate();
    return date.isAfter(DateTime.now().add(const Duration(hours: 24)));
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final String? id = appointment['id'] as String?;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cancel Appointment',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: const Text(
          'Are you sure you want to cancel this appointment? You will need to request a new checkup if you still wish to be seen.',
          style: TextStyle(fontFamily: 'Regular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style:
                  TextStyle(color: Colors.grey.shade700, fontFamily: 'Medium'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes, Cancel',
              style: TextStyle(color: primary, fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('appointments').doc(id).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'patient',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Appointment cancelled successfully',
              style: TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadUserAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to cancel appointment. Please try again.',
              style: TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final String status = (appointment['status'] ?? 'Pending').toString();
    final String notes = (appointment['notes'] ?? '').toString();
    String message;

    if (status == 'Completed') {
      if (notes.isNotEmpty) {
        message = notes;
      } else {
        message = 'Sorry, there\'s no available recommendation for you.';
      }
    } else if (status == 'Cancelled') {
      message = 'Sorry, there\'s no available recommendation for you.';
    } else if (status == 'No-show') {
      message = 'Please request appointment again.';
    } else {
      message = 'This appointment is still active.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Appointment Details',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Regular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: primary, fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    'Book & Notification Appointment',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Bold',
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Request a checkup and manage your appointments',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openRequestCheckup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.note_add,
                            color: Colors.white, size: 18),
                        label: Text(
                          widget.patientType == 'POSTNATAL'
                              ? 'Request Postnatal Checkup'
                              : 'Request Checkup',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'Bold',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _buildTabButton('PENDING & UPCOMING', 0),
                      const SizedBox(width: 8),
                      _buildTabButton('APPOINTMENT HISTORY', 1),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Loading State
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE91E63),
                      ),
                    )

                  // Appointments List
                  else ...[
                    Builder(
                      builder: (context) {
                        final upcoming = _appointments
                            .where(_isUpcomingAppointment)
                            .toList();
                        final history = _appointments
                            .where((a) => !_isUpcomingAppointment(a))
                            .toList();
                        final currentList =
                            _selectedTabIndex == 0 ? upcoming : history;

                        if (currentList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _selectedTabIndex == 0
                                      ? 'No Pending or Upcoming Appointments'
                                      : 'No Appointment History',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'Bold',
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.patientType == 'PRENATAL'
                                      ? 'Submit a checkup request using the button above.'
                                      : 'Book your first appointment using the button below.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Regular',
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: currentList
                              .map((appointment) => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: _buildAppointmentCard(
                                      appointment,
                                      isUpcoming: _selectedTabIndex == 0,
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
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
                Text(
                  '${widget.patientType} PATIENT',
                  style: const TextStyle(
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
          _buildMenuItem('HISTORY OF\nCHECK UP', false),
          _buildMenuItem('REQUEST &\nNOTIFICATION APPOINTMENT', true),
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
            if (widget.patientType == 'PRENATAL') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrenatalDashboardScreen(
                    openPersonalDetailsOnLoad: true,
                  ),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PostnatalDashboardScreen(
                    openPersonalDetailsOnLoad: true,
                  ),
                ),
              );
            }
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
        if (widget.patientType == 'PRENATAL') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const PrenatalDashboardScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const PostnatalDashboardScreen()),
          );
        }
        break;
      case 'HISTORY OF\nCHECK UP':
        if (widget.patientType == 'PRENATAL') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const PrenatalHistoryCheckupScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const PostnatalHistoryCheckupScreen()),
          );
        }
        break;
      case 'REQUEST &\nNOTIFICATION APPOINTMENT':
        // Already on this screen
        break;
      case 'TRANSFER OF\nRECORD REQUEST':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  TransferRecordRequestScreen(patientType: widget.patientType)),
        );
        break;
    }
  }

  Widget _buildAppointmentCard(
    Map<String, dynamic> appointment, {
    required bool isUpcoming,
  }) {
    String rawStatus = appointment['status'] ?? 'Pending';
    String displayStatus = _normalizeStatusLabel(rawStatus);
    Color statusColor;
    IconData statusIcon;

    switch (rawStatus) {
      case 'Confirmed':
      case 'Accepted':
      case 'Completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'Rescheduled':
        statusColor = Colors.blue;
        statusIcon = Icons.update;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'No-show':
        statusColor = Colors.grey;
        statusIcon = Icons.report_problem;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Type and Status
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appointment['appointmentType'] ?? 'Clinic',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      displayStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Bold',
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Appointment Details
          Row(
            children: [
              // Left Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatAppointmentDateTime(appointment),
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: Colors.black,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${appointment['reason'] ?? 'Not specified'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (appointment['notes'] != null &&
                        appointment['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Notes: ${appointment['notes']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Timestamp
          if (appointment['createdAt'] != null)
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Booked on ${_formatTimestamp(appointment['createdAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isUpcoming && _canCancelAppointment(appointment))
                TextButton(
                  onPressed: () => _cancelAppointment(appointment),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Bold',
                      color: Colors.red,
                    ),
                  ),
                )
              else if (!isUpcoming)
                TextButton(
                  onPressed: () => _showAppointmentDetails(appointment),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      fontFamily: 'Bold',
                      color: primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        date = DateTime.now();
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatAppointmentDateTime(Map<String, dynamic> appointment) {
    // Handle new appointment structure with appointmentDate
    if (appointment.containsKey('appointmentDate')) {
      Timestamp dateTimestamp = appointment['appointmentDate'];
      DateTime date = dateTimestamp.toDate();
      String timeSlot = appointment['timeSlot'] ?? 'Unknown Time';
      return '${_formatDate(date)}, $timeSlot';
    }

    // Handle old structure for backward compatibility
    String day = appointment['day'] ?? 'Unknown Day';
    String timeSlot = appointment['timeSlot'] ?? 'Unknown Time';
    return '$day, $timeSlot';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _normalizeStatusLabel(String rawStatus) {
    if (rawStatus == 'Accepted') {
      return 'Approved';
    }
    return rawStatus;
  }

  Widget _buildTabButton(String label, int index) {
    final bool isActive = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color: isActive ? Colors.white : primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
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
