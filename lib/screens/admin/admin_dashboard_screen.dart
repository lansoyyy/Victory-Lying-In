import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:maternity_clinic/screens/admin/admin_appointment_scheduling_screen.dart';
import 'package:maternity_clinic/screens/admin/admin_appointment_management_screen.dart';
import 'package:maternity_clinic/screens/admin/admin_patient_records_screen.dart';
import 'package:maternity_clinic/screens/admin/admin_transfer_requests_screen.dart';
import '../../utils/colors.dart';
import '../auth/home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String userRole;
  final String userName;
  final bool openAddStaffOnLoad;
  final bool openChangePasswordOnLoad;
  final bool openHistoryLogsOnLoad;

  const AdminDashboardScreen({
    super.key,
    required this.userRole,
    required this.userName,
    this.openAddStaffOnLoad = false,
    this.openChangePasswordOnLoad = false,
    this.openHistoryLogsOnLoad = false,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  int _prenatalCount = 0;
  int _postnatalCount = 0;
  int _pendingAppointments = 0;
  int _acceptedAppointments = 0;
  int _cancelledAppointments = 0;
  int _prenatalAppointments = 0;
  int _postnatalAppointments = 0;
  Map<int, int> _prenatalYearlyCount = {};
  Map<int, int> _postnatalYearlyCount = {};
  int _todaysAppointments = 0;
  int _highRiskPatients = 0;

  // Cached datasets for PDF exports
  List<Map<String, dynamic>> _prenatalPatients = [];
  List<Map<String, dynamic>> _postnatalPatients = [];
  List<Map<String, dynamic>> _appointmentsAll = [];
  Map<String, Map<String, dynamic>> _latestPrenatalAppointments = {};
  Map<String, Map<String, dynamic>> _latestPostnatalAppointments = {};

  // Age group statistics
  Map<String, int> _ageGroupCounts = {
    '12-19': 0,
    '20-29': 0,
    '30-39': 0,
    '40+': 0,
  };

  // Daily patient statistics (by appointment date)
  Map<DateTime, int> _dailyPatientCounts = {};

  // History logs (admin only)
  List<Map<String, dynamic>> _historyLogs = [];

  bool _isLoading = true;

  // Check if current user is admin
  bool get _isAdmin => widget.userRole == 'admin';

  // Check if current user is nurse
  bool get _isNurse => widget.userRole == 'nurse';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.openAddStaffOnLoad) {
        _showAddStaffDialog();
      } else if (widget.openChangePasswordOnLoad) {
        _showChangePasswordDialog();
      } else if (widget.openHistoryLogsOnLoad) {
        _scrollToHistoryLogs();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // Fetch prenatal and postnatal counts
      final prenatalSnapshot = await _firestore
          .collection('users')
          .where('patientType', isEqualTo: 'PRENATAL')
          .get();

      final postnatalSnapshot = await _firestore
          .collection('users')
          .where('patientType', isEqualTo: 'POSTNATAL')
          .get();

      // Fetch all appointments
      final appointmentsSnapshot =
          await _firestore.collection('appointments').get();

      // Cache basic datasets for later PDF exports
      final List<Map<String, dynamic>> prenatalPatients = [];
      final List<Map<String, dynamic>> postnatalPatients = [];
      final List<Map<String, dynamic>> allAppointments = [];
      final Map<String, String> userPatientTypeById = {};

      for (var doc in prenatalSnapshot.docs) {
        final data = doc.data();
        prenatalPatients.add({'id': doc.id, ...data});
        userPatientTypeById[doc.id] = 'PRENATAL';
      }

      for (var doc in postnatalSnapshot.docs) {
        final data = doc.data();
        postnatalPatients.add({'id': doc.id, ...data});
        userPatientTypeById[doc.id] = 'POSTNATAL';
      }

      final DateTime today = DateTime.now();

      // Daily patient counts (by appointment date, excluding cancelled)
      final Map<DateTime, int> dailyCounts = {};

      // Count appointments by status
      int pending = 0;
      int accepted = 0;
      int completed = 0;
      int cancelled = 0;
      int prenatalAppts = 0;
      int postnatalAppts = 0;
      int todaysAppointments = 0;
      int highRiskCount = 0;

      // Track latest relevant appointments per patient for risk computation
      final Map<String, DateTime> prenatalLatestDates = {};
      final Map<String, Map<String, dynamic>> prenatalLatestAppointments = {};
      final Map<String, DateTime> postnatalLatestDates = {};
      final Map<String, Map<String, dynamic>> postnatalLatestAppointments = {};

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        allAppointments.add(data);
        String status = data['status']?.toString().toLowerCase() ?? '';
        String appointmentType = data['appointmentType']?.toString() ?? '';
        String? userId = data['userId']?.toString();
        String patientType =
            (userId != null && userPatientTypeById.containsKey(userId))
                ? userPatientTypeById[userId]!
                : data['patientType']?.toString().toUpperCase() ?? '';
        data['patientType'] = patientType;

        DateTime? appointmentDate;
        if (data['appointmentDate'] is Timestamp) {
          appointmentDate = (data['appointmentDate'] as Timestamp).toDate();

          if (appointmentDate.year == today.year &&
              appointmentDate.month == today.month &&
              appointmentDate.day == today.day &&
              status != 'cancelled') {
            todaysAppointments++;
          }
        }

        if (appointmentDate != null && status != 'cancelled') {
          final dayKey = DateTime(
            appointmentDate.year,
            appointmentDate.month,
            appointmentDate.day,
          );
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
        }

        DateTime sortKey;
        if (appointmentDate != null) {
          sortKey = appointmentDate;
        } else if (data['createdAt'] is Timestamp) {
          sortKey = (data['createdAt'] as Timestamp).toDate();
        } else {
          sortKey = DateTime.fromMillisecondsSinceEpoch(0);
        }

        // Count by status
        if (status == 'pending') {
          pending++;
        } else if (status == 'accepted') {
          accepted++;
        } else if (status == 'completed') {
          completed++;
        } else if (status == 'cancelled') {
          cancelled++;
        }

        // Count by patient type
        if (patientType == 'PRENATAL') {
          prenatalAppts++;
        } else if (patientType == 'POSTNATAL') {
          postnatalAppts++;
        }

        // Track latest appointment per patient for risk assessment
        if (userId != null && userId.isNotEmpty) {
          if (patientType == 'PRENATAL' &&
              (appointmentType == 'Prenatal Checkup' ||
                  appointmentType == 'Initial Checkup' ||
                  appointmentType == 'Ultrasound')) {
            final existingDate = prenatalLatestDates[userId];
            if (existingDate == null || sortKey.isAfter(existingDate)) {
              prenatalLatestDates[userId] = sortKey;
              prenatalLatestAppointments[userId] = data;
            }
          } else if (patientType == 'POSTNATAL' &&
              appointmentType == 'Postnatal Checkup') {
            final existingDate = postnatalLatestDates[userId];
            if (existingDate == null || sortKey.isAfter(existingDate)) {
              postnatalLatestDates[userId] = sortKey;
              postnatalLatestAppointments[userId] = data;
            }
          }
        }
      }

      // Process age group data
      Map<String, int> ageGroups = {
        '12-19': 0,
        '20-29': 0,
        '30-39': 0,
        '40+': 0,
      };

      // Process prenatal patients for age groups
      for (var doc in prenatalSnapshot.docs) {
        final data = doc.data();
        if (data['age'] != null) {
          int age = data['age'] as int;
          if (age >= 12 && age <= 19) {
            ageGroups['12-19'] = (ageGroups['12-19'] ?? 0) + 1;
          } else if (age >= 20 && age <= 29) {
            ageGroups['20-29'] = (ageGroups['20-29'] ?? 0) + 1;
          } else if (age >= 30 && age <= 39) {
            ageGroups['30-39'] = (ageGroups['30-39'] ?? 0) + 1;
          } else if (age >= 40) {
            ageGroups['40+'] = (ageGroups['40+'] ?? 0) + 1;
          }
        }
      }

      // Process postnatal patients for age groups
      for (var doc in postnatalSnapshot.docs) {
        final data = doc.data();
        if (data['age'] != null) {
          int age = data['age'] as int;
          if (age >= 12 && age <= 19) {
            ageGroups['12-19'] = (ageGroups['12-19'] ?? 0) + 1;
          } else if (age >= 20 && age <= 29) {
            ageGroups['20-29'] = (ageGroups['20-29'] ?? 0) + 1;
          } else if (age >= 30 && age <= 39) {
            ageGroups['30-39'] = (ageGroups['30-39'] ?? 0) + 1;
          } else if (age >= 40) {
            ageGroups['40+'] = (ageGroups['40+'] ?? 0) + 1;
          }
        }
      }

      // Fetch yearly counts for history chart
      Map<int, int> prenatalYearly = {};
      Map<int, int> postnatalYearly = {};

      for (var doc in prenatalSnapshot.docs) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          DateTime date = (data['createdAt'] as Timestamp).toDate();
          int year = date.year;
          prenatalYearly[year] = (prenatalYearly[year] ?? 0) + 1;
        }
      }

      for (var doc in postnatalSnapshot.docs) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          DateTime date = (data['createdAt'] as Timestamp).toDate();
          int year = date.year;
          postnatalYearly[year] = (postnatalYearly[year] ?? 0) + 1;
        }
      }

      // Fetch history logs (if any)
      List<Map<String, dynamic>> historyLogs = [];
      try {
        final historySnapshot = await _firestore
            .collection('historyLogs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get();
        for (var doc in historySnapshot.docs) {
          final data = doc.data();
          historyLogs.add({
            'id': doc.id,
            ...data,
          });
        }
      } catch (_) {
        historyLogs = [];
      }

      // Compute high risk patients (prenatal + postnatal)
      for (var doc in prenatalSnapshot.docs) {
        final data = doc.data();
        final latestAppt = prenatalLatestAppointments[doc.id];
        if (_isPrenatalHighRisk(data, latestAppt)) {
          highRiskCount++;
        }
      }

      for (var doc in postnatalSnapshot.docs) {
        final data = doc.data();
        final latestAppt = postnatalLatestAppointments[doc.id];
        if (_isPostnatalHighRisk(data, latestAppt)) {
          highRiskCount++;
        }
      }

      if (mounted) {
        setState(() {
          _prenatalCount = prenatalSnapshot.docs.length;
          _postnatalCount = postnatalSnapshot.docs.length;
          _pendingAppointments = pending;
          _acceptedAppointments = accepted;
          _acceptedAppointments = accepted;
          _cancelledAppointments = cancelled;
          _prenatalAppointments = prenatalAppts;
          _postnatalAppointments = postnatalAppts;
          _prenatalYearlyCount = prenatalYearly;
          _postnatalYearlyCount = postnatalYearly;
          _prenatalPatients = prenatalPatients;
          _postnatalPatients = postnatalPatients;
          _appointmentsAll = allAppointments;
          _latestPrenatalAppointments = prenatalLatestAppointments;
          _latestPostnatalAppointments = postnatalLatestAppointments;
          _ageGroupCounts = ageGroups;
          _dailyPatientCounts = dailyCounts;
          _todaysAppointments = todaysAppointments;
          _highRiskPatients = highRiskCount;
          _historyLogs = historyLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),

          // Main Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dashboard Header
                        Container(
                          margin: const EdgeInsets.only(bottom: 30),
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primary.withOpacity(0.9),
                                secondary.withOpacity(0.9)
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.dashboard_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ADMIN DASHBOARD',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontFamily: 'Bold',
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Welcome back, ${widget.userName}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontFamily: 'Medium',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Home Quick Stats Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Pending Requests',
                                '$_pendingAppointments',
                                Icons.pending_actions_rounded,
                                Colors.orange,
                                onTap: () {
                                  _handleMenuNavigation(
                                      'APPOINTMENT\nSCHEDULING');
                                },
                                onPdf: () {
                                  _exportPendingRequestsPdf();
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildStatCard(
                                "Today's Appointments",
                                '$_todaysAppointments',
                                Icons.today_rounded,
                                Colors.blue,
                                onTap: () {
                                  _handleMenuNavigation(
                                      'APPOINTMENT\nSCHEDULING');
                                },
                                onPdf: () {
                                  _exportTodaysAppointmentsPdf();
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildStatCard(
                                'High Risk Patients',
                                '$_highRiskPatients',
                                Icons.warning_amber_rounded,
                                Colors.red,
                                onPdf: () {
                                  _exportHighRiskPatientsPdf();
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildStatCard(
                                'Total Active Patients',
                                '${_prenatalCount + _postnatalCount}',
                                Icons.people_rounded,
                                const Color(0xFF5DCED9),
                                onPdf: () {
                                  _exportTotalActivePatientsPdf();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Top Row - Charts (Admin and Nurse)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildPrenatalPostnatalChart(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildAgeGroupChart(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildDailyPatientChart(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Bottom - Line Chart
                        _buildHistoryCountingChart(),
                        const SizedBox(height: 30),

                        // Nurse Dashboard - Transfer Requests
                        if (_isNurse) ...[
                          _buildNurseTransferRequestsSection(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLogsSection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HISTORY LOGS',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This section helps you track who did what and when inside the system.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '- Date & Time: Shows the exact moment when an action happened, so you can follow the sequence of events and see when changes were made.',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Regular',
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            '- User: Identifies who performed the action (admin, nurse, or patient).',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Regular',
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            '- Action Performed: Explains what was done, such as login, update, create, approve, or delete.',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Regular',
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _historyLogs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No history logs yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Bold',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Bold',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'User',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Bold',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'Action Performed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Bold',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _historyLogs.length,
                            itemBuilder: (context, index) {
                              final log = _historyLogs[index];
                              DateTime? ts;
                              final rawTs = log['timestamp'];
                              if (rawTs is Timestamp) {
                                ts = rawTs.toDate();
                              }
                              String dateText = 'N/A';
                              String timeText = 'N/A';
                              if (ts != null) {
                                dateText =
                                    '${ts.year.toString().padLeft(4, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
                                timeText =
                                    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                              }

                              final String roleRaw =
                                  (log['role'] ?? log['userRole'] ?? '')
                                      .toString();
                              final String userName = (log['userName'] ??
                                      log['user'] ??
                                      log['name'] ??
                                      '')
                                  .toString();

                              String userLabel;
                              if (userName.isNotEmpty && roleRaw.isNotEmpty) {
                                userLabel =
                                    '$userName (${roleRaw.toUpperCase()})';
                              } else if (userName.isNotEmpty) {
                                userLabel = userName;
                              } else if (roleRaw.isNotEmpty) {
                                userLabel = roleRaw.toUpperCase();
                              } else {
                                userLabel = '-';
                              }
                              final String action = (log['action'] ??
                                      log['description'] ??
                                      log['details'] ??
                                      '')
                                  .toString();

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        dateText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Regular',
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        timeText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Regular',
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        userLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Bold',
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        action.isNotEmpty
                                            ? action
                                            : 'No details provided',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Regular',
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPatientChart() {
    if (_dailyPatientCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No Cater Daily data yet',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      );
    }

    final List<DateTime> allDays = _dailyPatientCounts.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    final List<DateTime> days =
        allDays.length > 7 ? allDays.sublist(allDays.length - 7) : allDays;

    final List<FlSpot> spots = [];
    double maxY = 0;
    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final count = (_dailyPatientCounts[d] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
      if (count > maxY) maxY = count;
    }
    if (maxY == 0) maxY = 1;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CATER DAILY',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                color: Colors.redAccent,
                tooltip: 'View & Print PDF',
                onPressed: _exportCaterDailyPdf,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).clamp(1, maxY),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length) {
                          return const Text('');
                        }
                        final d = days[index];
                        return Text(
                          '${d.month}/${d.day}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                minX: 0,
                maxX: (days.length - 1).toDouble(),
                minY: 0,
                maxY: maxY + 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: primary.withOpacity(0.1),
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

  Future<void> _exportSimpleStatPdf(String title, String value) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _buildPrintedOnLabel(),
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Value: $value',
                  style: pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  String _buildPrintedOnLabel() {
    final now = DateTime.now();
    final String date =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year.toString().padLeft(4, '0')}';
    int hour = now.hour % 12;
    if (hour == 0) hour = 12;
    final String minute = now.minute.toString().padLeft(2, '0');
    final String ampm = now.hour >= 12 ? 'PM' : 'AM';
    return 'Printed on: $date $hour:$minute $ampm';
  }

  pw.Widget _buildPdfTable(List<String> headers, List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map(
                  (cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      cell,
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _exportPendingRequestsPdf() async {
    final doc = pw.Document();

    final pending = _appointmentsAll
        .where((a) => (a['status'] ?? '').toString().toLowerCase() == 'pending')
        .toList();

    final prenatal = pending
        .where((a) =>
            (a['patientType'] ?? '').toString().toUpperCase() == 'PRENATAL')
        .toList();
    final postnatal = pending
        .where((a) =>
            (a['patientType'] ?? '').toString().toUpperCase() == 'POSTNATAL')
        .toList();

    int compareCreatedAt(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ca = a['createdAt'];
      final cb = b['createdAt'];
      if (ca is Timestamp && cb is Timestamp) {
        return cb.compareTo(ca);
      }
      return 0;
    }

    prenatal.sort(compareCreatedAt);
    postnatal.sort(compareCreatedAt);

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'Pending Requests',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Prenatal Pending Requests',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (prenatal.isEmpty)
              pw.Text('No prenatal pending requests.')
            else
              _buildPdfTable(
                ['Name', 'Appointment Type', 'Appointment Request Date'],
                prenatal.map((a) {
                  String name = a['fullName']?.toString() ?? 'N/A';
                  String type = a['appointmentType']?.toString() ?? 'N/A';
                  String dateText = 'N/A';
                  final ts = a['createdAt'];
                  if (ts is Timestamp) {
                    final d = ts.toDate();
                    dateText =
                        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
                  }
                  return [name, type, dateText];
                }).toList(),
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Postnatal Pending Requests',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (postnatal.isEmpty)
              pw.Text('No postnatal pending requests.')
            else
              _buildPdfTable(
                ['Name', 'Appointment Type', 'Appointment Request Date'],
                postnatal.map((a) {
                  String name = a['fullName']?.toString() ?? 'N/A';
                  String type = a['appointmentType']?.toString() ?? 'N/A';
                  String dateText = 'N/A';
                  final ts = a['createdAt'];
                  if (ts is Timestamp) {
                    final d = ts.toDate();
                    dateText =
                        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
                  }
                  return [name, type, dateText];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportTodaysAppointmentsPdf() async {
    final doc = pw.Document();
    final DateTime today = DateTime.now();

    final todays = _appointmentsAll.where((a) {
      if (a['appointmentDate'] is! Timestamp) return false;
      final ts = a['appointmentDate'] as Timestamp;
      final d = ts.toDate();
      final status = (a['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled') return false;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList()
      ..sort((a, b) {
        final na = a['fullName']?.toString() ?? '';
        final nb = b['fullName']?.toString() ?? '';
        return na.compareTo(nb);
      });

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              "Today's Appointments",
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            if (todays.isEmpty)
              pw.Text('No appointments scheduled for today.')
            else
              _buildPdfTable(
                [
                  'Name',
                  'Maternity Status',
                  'Appointment Type',
                  'Appointment Date'
                ],
                todays.map((a) {
                  final name = a['fullName']?.toString() ?? 'N/A';
                  final pt = (a['patientType'] ?? '').toString().toUpperCase();
                  final maternity = pt == 'PRENATAL'
                      ? 'Prenatal'
                      : pt == 'POSTNATAL'
                          ? 'Postnatal'
                          : 'N/A';
                  final type = a['appointmentType']?.toString() ?? 'N/A';
                  String dateText = 'N/A';
                  final ts = a['appointmentDate'];
                  if (ts is Timestamp) {
                    final d = ts.toDate();
                    dateText =
                        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
                  }
                  return [name, maternity, type, dateText];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportHighRiskPatientsPdf() async {
    final doc = pw.Document();

    final List<List<String>> prenatalRows = [];
    for (final patient in _prenatalPatients) {
      final String id = patient['id']?.toString() ?? '';
      final appt = _latestPrenatalAppointments[id];
      if (!_isPrenatalHighRisk(patient, appt)) continue;

      final name = patient['name']?.toString() ?? 'N/A';
      String dateText = 'N/A';
      String bpText = 'N/A';
      String fhrText = 'N/A';
      String fundalText = 'N/A';
      String riskText = patient['riskStatus']?.toString().isNotEmpty == true
          ? patient['riskStatus'].toString()
          : 'HIGH RISK';

      if (appt != null) {
        DateTime? dateTime;
        if (appt['appointmentDate'] is Timestamp) {
          dateTime = (appt['appointmentDate'] as Timestamp).toDate();
        } else if (appt['createdAt'] is Timestamp) {
          dateTime = (appt['createdAt'] as Timestamp).toDate();
        }
        if (dateTime != null) {
          dateText =
              '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
        }

        final bpValue = appt['checkupBloodPressure'];
        if (bpValue != null && bpValue.toString().trim().isNotEmpty) {
          bpText = bpValue.toString();
        } else {
          final sys = appt['checkupBP_Systolic'];
          final dia = appt['checkupBP_Diastolic'];
          if (sys != null && dia != null) {
            bpText = '${sys.toString()}/${dia.toString()}';
          }
        }
        final fhr = appt['checkupFetalHeartRateBpm'];
        if (fhr != null) {
          fhrText = fhr.toString();
        }
        final fundal = appt['checkupFundalHeightCm'];
        if (fundal != null) {
          fundalText = fundal.toString();
        }
        if (appt['visitRiskStatus'] != null &&
            appt['visitRiskStatus'].toString().trim().isNotEmpty) {
          riskText = appt['visitRiskStatus'].toString();
        }
      }

      prenatalRows.add([name, dateText, bpText, fhrText, fundalText, riskText]);
    }

    final List<List<String>> postnatalRows = [];
    for (final patient in _postnatalPatients) {
      final String id = patient['id']?.toString() ?? '';
      final appt = _latestPostnatalAppointments[id];
      if (!_isPostnatalHighRisk(patient, appt)) continue;

      final name = patient['name']?.toString() ?? 'N/A';
      String dateText = 'N/A';
      String bpText = 'N/A';
      String riskText = patient['riskStatus']?.toString().isNotEmpty == true
          ? patient['riskStatus'].toString()
          : 'HIGH RISK';

      if (appt != null) {
        DateTime? dateTime;
        if (appt['appointmentDate'] is Timestamp) {
          dateTime = (appt['appointmentDate'] as Timestamp).toDate();
        } else if (appt['createdAt'] is Timestamp) {
          dateTime = (appt['createdAt'] as Timestamp).toDate();
        }
        if (dateTime != null) {
          dateText =
              '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
        }

        final bpValue =
            appt['checkupBloodPressure'] ?? appt['currentBloodPressure'];
        if (bpValue != null && bpValue.toString().trim().isNotEmpty) {
          bpText = bpValue.toString();
        }
        if (appt['visitRiskStatus'] != null &&
            appt['visitRiskStatus'].toString().trim().isNotEmpty) {
          riskText = appt['visitRiskStatus'].toString();
        }
      }

      postnatalRows.add([name, dateText, bpText, riskText]);
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'High Risk Patients',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Prenatal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (prenatalRows.isEmpty)
              pw.Text('No prenatal high risk patients.')
            else
              _buildPdfTable(
                [
                  'Name',
                  'Date',
                  'Blood Pressure (mmHg)',
                  'Fetal Heart Rate (bpm)',
                  'Fundal Height (cm)',
                  'Risk Classification'
                ],
                prenatalRows,
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Postnatal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (postnatalRows.isEmpty)
              pw.Text('No postnatal high risk patients.')
            else
              _buildPdfTable(
                [
                  'Name',
                  'Date',
                  'Blood Pressure (mmHg)',
                  'Risk Classification'
                ],
                postnatalRows,
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportTotalActivePatientsPdf() async {
    final doc = pw.Document();

    final prenatalActive = _prenatalPatients;
    final postnatalActive = _postnatalPatients;

    List<List<String>> buildRows(List<Map<String, dynamic>> patients) {
      return patients.map((p) {
        final name = p['name']?.toString() ?? 'N/A';
        final email = p['email']?.toString() ?? 'N/A';
        final contact = p['contactNumber']?.toString() ?? 'N/A';
        String dobText = 'N/A';
        final dobTs = p['dob'];
        if (dobTs is Timestamp) {
          final d = dobTs.toDate();
          dobText =
              '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
        }
        return [name, email, contact, dobText];
      }).toList();
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'Total Active Patients',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Prenatal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (prenatalActive.isEmpty)
              pw.Text('No prenatal patients found.')
            else
              _buildPdfTable(
                ['Name', 'Email', 'Contact No.', 'Date of Birth'],
                buildRows(prenatalActive),
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Postnatal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (postnatalActive.isEmpty)
              pw.Text('No postnatal patients found.')
            else
              _buildPdfTable(
                ['Name', 'Email', 'Contact No.', 'Date of Birth'],
                buildRows(postnatalActive),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportPrenatalPostnatalPatientsPdf() async {
    final doc = pw.Document();

    List<List<String>> buildRows(List<Map<String, dynamic>> patients) {
      return patients.map((p) {
        final name = p['name']?.toString() ?? 'N/A';
        final email = p['email']?.toString() ?? 'N/A';
        final contact = p['contactNumber']?.toString() ?? 'N/A';
        String dobText = 'N/A';
        final dobTs = p['dob'];
        if (dobTs is Timestamp) {
          final d = dobTs.toDate();
          dobText =
              '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
        }
        return [name, email, contact, dobText];
      }).toList();
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'Prenatal and Postnatal Patients',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Prenatal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (_prenatalPatients.isEmpty)
              pw.Text('No prenatal patients found.')
            else
              _buildPdfTable(
                ['Name', 'Email', 'Contact No.', 'Date of Birth'],
                buildRows(_prenatalPatients),
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Postnatal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            if (_postnatalPatients.isEmpty)
              pw.Text('No postnatal patients found.')
            else
              _buildPdfTable(
                ['Name', 'Email', 'Contact No.', 'Date of Birth'],
                buildRows(_postnatalPatients),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportAgeGroupDistributionPdf() async {
    final doc = pw.Document();

    final List<Map<String, dynamic>> allPatients = [
      ..._prenatalPatients.map((p) => {...p, 'patientType': 'Prenatal'}),
      ..._postnatalPatients.map((p) => {...p, 'patientType': 'Postnatal'}),
    ];

    allPatients.removeWhere((p) => p['age'] == null);

    allPatients.sort((a, b) {
      final int aa = (a['age'] is int)
          ? a['age'] as int
          : int.tryParse(a['age']?.toString() ?? '0') ?? 0;
      final int bb = (b['age'] is int)
          ? b['age'] as int
          : int.tryParse(b['age']?.toString() ?? '0') ?? 0;
      return aa.compareTo(bb);
    });

    final rows = allPatients.map((p) {
      final ageVal = (p['age'] is int)
          ? p['age'] as int
          : int.tryParse(p['age']?.toString() ?? '0') ?? 0;
      final name = p['name']?.toString() ?? 'N/A';
      final email = p['email']?.toString() ?? 'N/A';
      final contact = p['contactNumber']?.toString() ?? 'N/A';
      final status = p['patientType']?.toString() ?? 'N/A';
      return [
        ageVal.toString(),
        name,
        email,
        contact,
        status,
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'Age Group Distribution (Ascending)',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            if (rows.isEmpty)
              pw.Text('No patient age data available.')
            else
              _buildPdfTable(
                ['Age', 'Name', 'Email', 'Contact', 'Maternal Status'],
                rows,
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportCaterDailyPdf() async {
    final doc = pw.Document();

    final entries = _dailyPatientCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final rows = <List<String>>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final d = e.key;
      final count = e.value;
      final dateText =
          '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
      rows.add([(i + 1).toString(), dateText, count.toString()]);
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'Cater Daily',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            if (rows.isEmpty)
              pw.Text('No daily data available.')
            else
              _buildPdfTable(
                ['No.', 'Date', 'Count'],
                rows,
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportPatientHistoryTrendsPdf() async {
    final doc = pw.Document();
    final int currentYear = DateTime.now().year;

    final List<Map<String, dynamic>> rowsSource = [];

    for (final p in _prenatalPatients) {
      final ts = p['createdAt'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        if (d.year == currentYear) {
          rowsSource.add({
            'name': p['name']?.toString() ?? 'N/A',
            'status': 'Prenatal',
          });
        }
      }
    }

    for (final p in _postnatalPatients) {
      final ts = p['createdAt'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        if (d.year == currentYear) {
          rowsSource.add({
            'name': p['name']?.toString() ?? 'N/A',
            'status': 'Postnatal',
          });
        }
      }
    }

    rowsSource.sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    final rows = <List<String>>[];
    for (int i = 0; i < rowsSource.length; i++) {
      final r = rowsSource[i];
      rows.add([
        (i + 1).toString(),
        r['name']?.toString() ?? 'N/A',
        r['status']?.toString() ?? 'N/A',
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'Patient History Trends (${currentYear.toString()})',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _buildPrintedOnLabel(),
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            if (rows.isEmpty)
              pw.Text('No patient history data for the current year.')
            else
              _buildPdfTable(
                ['No.', 'Name', 'Maternity Status'],
                rows,
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
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
          _buildMenuItem('DATA GRAPHS', true),
          _buildMenuItem('APPOINTMENT MANAGEMENT', false),
          _buildMenuItem('APPROVE SCHEDULES', false),
          _buildMenuItem('PATIENT RECORDS', false),

          // Logout Menu Item
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildLogoutMenuItem(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _handleMenuNavigation(title);
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

  Widget _buildLogoutMenuItem() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _showLogoutConfirmationDialog();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              left: BorderSide(
                color: Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'LOGOUT',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontFamily: 'Medium',
                  height: 1.3,
                ),
              ),
            ],
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
              Navigator.pop(context); // Close dialog
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

  void _handleMenuNavigation(String title) {
    Widget screen;
    switch (title) {
      case 'ADD NEW STAFF/NURSE':
        if (!_isAdmin) {
          _showAccessDeniedDialog();
          return;
        }
        _showAddStaffDialog();
        return;
      case 'CHANGE PASSWORD':
        if (!_isAdmin) {
          _showAccessDeniedDialog();
          return;
        }
        _showChangePasswordDialog();
        return;
      case 'HISTORY LOGS':
        if (!_isAdmin) {
          _showAccessDeniedDialog();
          return;
        }
        _scrollToHistoryLogs();
        return;
      case 'DATA GRAPHS':
        // Already on this screen
        return;
      case 'APPOINTMENT MANAGEMENT':
        screen = AdminAppointmentManagementScreen(
          userRole: widget.userRole,
          userName: widget.userName,
        );
        break;
      case 'APPROVE SCHEDULES':
        screen = AdminAppointmentSchedulingScreen(
          userRole: widget.userRole,
          userName: widget.userName,
        );
        break;
      case 'PATIENT RECORDS':
        screen = AdminPatientRecordsScreen(
          userRole: widget.userRole,
          userName: widget.userName,
        );
        break;
      default:
        return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _scrollToHistoryLogs() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _showAddStaffDialog() {
    if (!_isAdmin) {
      _showAccessDeniedDialog();
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Add New Staff/Nurse',
                style: TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Role: Nurse (staff)',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final username = usernameController.text.trim();
                          final password = passwordController.text.trim();
                          final confirm = confirmPasswordController.text.trim();

                          if (name.isEmpty ||
                              username.isEmpty ||
                              password.isEmpty ||
                              confirm.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please fill in all required fields'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (password != confirm) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Password and confirm do not match'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setStateDialog(() {
                            isSaving = true;
                          });

                          try {
                            final docRef = _firestore
                                .collection('staffAccounts')
                                .doc(username);
                            final existing = await docRef.get();
                            if (existing.exists) {
                              setStateDialog(() {
                                isSaving = false;
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Username already exists'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await docRef.set({
                              'username': username,
                              'name': name,
                              'role': 'nurse',
                              'password': password,
                              'createdAt': FieldValue.serverTimestamp(),
                              'createdBy': widget.userName,
                            });

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Staff account added'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setStateDialog(() {
                              isSaving = false;
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to add staff account'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
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

  void _showChangePasswordDialog() {
    if (!_isAdmin) {
      _showAccessDeniedDialog();
      return;
    }

    final TextEditingController currentController = TextEditingController();
    final TextEditingController newController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Change Password',
                style: TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: currentController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: newController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
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
                  onPressed: isSaving
                      ? null
                      : () {
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          final current = currentController.text.trim();
                          final newPass = newController.text.trim();
                          final confirm = confirmController.text.trim();

                          if (current.isEmpty ||
                              newPass.isEmpty ||
                              confirm.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please fill in all required fields'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (newPass.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'New password must be at least 6 characters'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (newPass != confirm) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'New password and confirm do not match'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setStateDialog(() {
                            isSaving = true;
                          });

                          try {
                            final docRef = _firestore
                                .collection('staffAccounts')
                                .doc('admin');
                            final snap = await docRef.get();

                            String storedPassword = 'admin123';
                            if (snap.exists) {
                              final data = snap.data() as Map<String, dynamic>?;
                              final pwd = data?['password']?.toString();
                              if (pwd != null && pwd.isNotEmpty) {
                                storedPassword = pwd;
                              }
                            }

                            if (current != storedPassword) {
                              setStateDialog(() {
                                isSaving = false;
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Current password is incorrect'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await docRef.set({
                              'username': 'admin',
                              'name': widget.userName,
                              'role': 'admin',
                              'password': newPass,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setStateDialog(() {
                              isSaving = false;
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update password'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
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

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Access Denied',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: Text(
          'This feature is only available to administrators. You are logged in as ${widget.userRole}.',
          style: const TextStyle(fontFamily: 'Regular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: primary, fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPrenatalHighRisk(
      Map<String, dynamic> patientData, Map<String, dynamic>? appointment) {
    // If staff/admin has manually set a HIGH RISK flag, honor it first.
    final manualRisk = patientData['riskStatus']?.toString().toUpperCase();
    if (manualRisk == 'HIGH RISK') {
      return true;
    }

    if (appointment == null) return false;

    bool highRisk = false;

    // High Blood Pressure medication
    if (appointment['highBloodPressureMedication'] == 'YES') {
      highRisk = true;
    }

    // Diabetes
    if (appointment['diagnosedWithDiabetes'] == 'YES') {
      highRisk = true;
    }

    // High Gravidity (5 or more pregnancies)
    final totalPregnancies =
        int.tryParse(appointment['totalPregnancies']?.toString() ?? '0') ?? 0;
    if (totalPregnancies >= 5) {
      highRisk = true;
    }

    // Age check (17 or younger OR 35 or older)
    int age;
    final rawAge = patientData['age'];
    if (rawAge is int) {
      age = rawAge;
    } else {
      age = int.tryParse(rawAge?.toString() ?? '0') ?? 0;
    }
    if (age <= 17 || age >= 35) {
      highRisk = true;
    }

    // Urgent symptoms in reason for visit
    final reasonForVisit =
        appointment['reasonForVisit']?.toString().toLowerCase() ?? '';
    if (reasonForVisit.contains('abnormal spotting') ||
        reasonForVisit.contains('bleeding') ||
        reasonForVisit.contains('severe pain')) {
      highRisk = true;
    }

    return highRisk;
  }

  bool _isPostnatalHighRisk(
      Map<String, dynamic> patientData, Map<String, dynamic>? appointment) {
    // If staff/admin has manually set a HIGH RISK flag, honor it first.
    final manualRisk = patientData['riskStatus']?.toString().toUpperCase();
    if (manualRisk == 'HIGH RISK') {
      return true;
    }

    if (appointment == null) return false;

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

    return highRisk;
  }

  Widget _buildPrenatalPostnatalChart() {
    int total = _prenatalCount + _postnatalCount;
    double prenatalPercent = total > 0 ? (_prenatalCount / total) * 100 : 0;
    double postnatalPercent = total > 0 ? (_postnatalCount / total) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRENATAL AND POSTNATAL',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                color: Colors.redAccent,
                tooltip: 'View & Print PDF',
                onPressed: _exportPrenatalPostnatalPatientsPdf,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: total > 0 ? 200 : 0,
            child: total > 0
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                      sections: [
                        if (_prenatalCount > 0)
                          PieChartSectionData(
                            value: _prenatalCount.toDouble(),
                            title:
                                'PRENATAL\n${prenatalPercent.toStringAsFixed(1)}%',
                            color: const Color(0xFF5DCED9),
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Bold',
                              color: Colors.white,
                            ),
                          ),
                        if (_postnatalCount > 0)
                          PieChartSectionData(
                            value: _postnatalCount.toDouble(),
                            title:
                                'POSTNATAL\n${postnatalPercent.toStringAsFixed(1)}%',
                            color: const Color(0xFF3F51B5),
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Bold',
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap, VoidCallback? onPdf}) {
    return MouseRegion(
      cursor:
          onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  if (onPdf != null)
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      color: Colors.redAccent,
                      tooltip: 'View & Print PDF',
                      onPressed: onPdf,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontFamily: 'Bold',
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Medium',
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgeGroupChart() {
    int totalPatients = _prenatalCount + _postnatalCount;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AGE GROUP DISTRIBUTION',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                color: Colors.redAccent,
                tooltip: 'View & Print PDF',
                onPressed: _exportAgeGroupDistributionPdf,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: totalPatients > 0
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        if (_ageGroupCounts['12-19']! > 0)
                          PieChartSectionData(
                            value: _ageGroupCounts['12-19']!.toDouble(),
                            title:
                                '12-19\n${((_ageGroupCounts['12-19']! / totalPatients) * 100).toStringAsFixed(1)}%',
                            color: const Color(0xFF9C27B0),
                            radius: 70,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Bold',
                              color: Colors.white,
                            ),
                          ),
                        if (_ageGroupCounts['20-29']! > 0)
                          PieChartSectionData(
                            value: _ageGroupCounts['20-29']!.toDouble(),
                            title:
                                '20-29\n${((_ageGroupCounts['20-29']! / totalPatients) * 100).toStringAsFixed(1)}%',
                            color: const Color(0xFF2196F3),
                            radius: 70,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Bold',
                              color: Colors.white,
                            ),
                          ),
                        if (_ageGroupCounts['30-39']! > 0)
                          PieChartSectionData(
                            value: _ageGroupCounts['30-39']!.toDouble(),
                            title:
                                '30-39\n${((_ageGroupCounts['30-39']! / totalPatients) * 100).toStringAsFixed(1)}%',
                            color: const Color(0xFF4CAF50),
                            radius: 70,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Bold',
                              color: Colors.white,
                            ),
                          ),
                        if (_ageGroupCounts['40+']! > 0)
                          PieChartSectionData(
                            value: _ageGroupCounts['40+']!.toDouble(),
                            title:
                                '40+\n${((_ageGroupCounts['40+']! / totalPatients) * 100).toStringAsFixed(1)}%',
                            color: const Color(0xFFFF9800),
                            radius: 70,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Bold',
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  )
                : const Center(
                    child: Text('No patient data yet',
                        style: TextStyle(fontSize: 14, color: Colors.grey))),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('12-19', const Color(0xFF9C27B0)),
              _buildLegendItem('20-29', const Color(0xFF2196F3)),
              _buildLegendItem('30-39', const Color(0xFF4CAF50)),
              _buildLegendItem('40+', const Color(0xFFFF9800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Medium',
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getPrenatalSpots() {
    List<FlSpot> spots = [];
    int currentYear = DateTime.now().year;
    for (int i = 0; i < 3; i++) {
      int year = currentYear - 2 + i;
      double count = (_prenatalYearlyCount[year] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
    }
    return spots;
  }

  List<FlSpot> _getPostnatalSpots() {
    List<FlSpot> spots = [];
    int currentYear = DateTime.now().year;
    for (int i = 0; i < 3; i++) {
      int year = currentYear - 2 + i;
      double count = (_postnatalYearlyCount[year] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
    }
    return spots;
  }

  double _calculateMaxY() {
    double maxPrenatal = 0;
    double maxPostnatal = 0;

    for (var count in _prenatalYearlyCount.values) {
      if (count > maxPrenatal) maxPrenatal = count.toDouble();
    }

    for (var count in _postnatalYearlyCount.values) {
      if (count > maxPostnatal) maxPostnatal = count.toDouble();
    }

    double max = maxPrenatal > maxPostnatal ? maxPrenatal : maxPostnatal;
    return max > 0 ? max + (max * 0.2) : 100; // Add 20% padding or minimum 100
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'Medium',
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCountingChart() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PATIENT HISTORY TRENDS',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                color: Colors.redAccent,
                tooltip: 'View & Print PDF',
                onPressed: _exportPatientHistoryTrendsPdf,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_prenatalYearlyCount.isNotEmpty ||
              _postnatalYearlyCount.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_postnatalYearlyCount.isNotEmpty)
                  _buildLegend('Postnatal', Colors.red),
                if (_postnatalYearlyCount.isNotEmpty &&
                    _prenatalYearlyCount.isNotEmpty)
                  const SizedBox(width: 30),
                if (_prenatalYearlyCount.isNotEmpty)
                  _buildLegend('Prenatal', const Color(0xFF3F51B5)),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1000,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          int currentYear = DateTime.now().year;
                          switch (value.toInt()) {
                            case 0:
                              return Text('${currentYear - 2}',
                                  style: const TextStyle(
                                      fontSize: 12, fontFamily: 'Regular'));
                            case 1:
                              return Text('${currentYear - 1}',
                                  style: const TextStyle(
                                      fontSize: 12, fontFamily: 'Regular'));
                            case 2:
                              return Text('$currentYear',
                                  style: const TextStyle(
                                      fontSize: 12, fontFamily: 'Regular'));
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: 1000,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Regular',
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  minX: 0,
                  maxX: 2,
                  minY: 0,
                  maxY: _calculateMaxY(),
                  lineBarsData: [
                    // Prenatal line (blue)
                    if (_prenatalYearlyCount.isNotEmpty)
                      LineChartBarData(
                        spots: _getPrenatalSpots(),
                        isCurved: true,
                        color: const Color(0xFF3F51B5),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: const Color(0xFF3F51B5),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF3F51B5).withOpacity(0.1),
                        ),
                      ),
                    // Postnatal line (red)
                    if (_postnatalYearlyCount.isNotEmpty)
                      LineChartBarData(
                        spots: _getPostnatalSpots(),
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: Colors.red,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.red.withOpacity(0.1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNurseTransferRequestsSection() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRANSFER REQUESTS',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminTransferRequestsScreen(
                        userRole: widget.userRole,
                        userName: widget.userName,
                      ),
                    ),
                  );
                },
                child: Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontFamily: 'Bold',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildNurseStatCard(
                  'Pending Requests',
                  '0',
                  Icons.pending_actions_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildNurseStatCard(
                  'Processing',
                  '0',
                  Icons.hourglass_empty_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildNurseStatCard(
                  'Completed',
                  '0',
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'View and manage transfer requests for both prenatal and postnatal records',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNurseStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Bold',
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Medium',
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder Screens
class PrenatalPatientRecordPlaceholder extends StatelessWidget {
  const PrenatalPatientRecordPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          'Prenatal Patient Record',
          style: TextStyle(fontFamily: 'Bold'),
        ),
      ),
      body: const Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: Text(
              'Prenatal Patient Record\n(Coming Soon)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Medium',
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PostnatalPatientRecordPlaceholder extends StatelessWidget {
  const PostnatalPatientRecordPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          'Postnatal Patient Record',
          style: TextStyle(fontFamily: 'Bold'),
        ),
      ),
      body: const Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: Text(
              'Postnatal Patient Record\n(Coming Soon)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Medium',
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppointmentSchedulingPlaceholder extends StatelessWidget {
  const AppointmentSchedulingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          'Appointment Scheduling',
          style: TextStyle(fontFamily: 'Bold'),
        ),
      ),
      body: const Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: Text(
              'Appointment Scheduling\n(Coming Soon)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Medium',
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
