import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maternity_clinic/services/audit_log_service.dart';
import 'package:maternity_clinic/services/notification_service.dart';
import '../../utils/colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_patient_records_screen.dart';
import 'admin_appointment_scheduling_screen.dart';
import 'admin_appointment_management_screen.dart';
import '../auth/home_screen.dart';

class AdminTransferRequestsScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const AdminTransferRequestsScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<AdminTransferRequestsScreen> createState() =>
      _AdminTransferRequestsScreenState();
}

class _AdminTransferRequestsScreenState
    extends State<AdminTransferRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _filterStatus = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTransferRequests();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransferRequests() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('transferRequests')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> requests = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> request = doc.data();
        request['id'] = doc.id;
        requests.add(request);
      }

      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching transfer requests: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      Map<String, dynamic>? requestData;
      try {
        final doc = await _firestore
            .collection('transferRequests')
            .doc(requestId)
            .get();
        requestData = doc.data();
      } catch (_) {
        requestData = null;
      }

      await _firestore.collection('transferRequests').doc(requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final String userId = (requestData?['userId'] ?? '').toString();
      final String userName = (requestData?['userName'] ?? '').toString();
      final String transferTo = (requestData?['transferTo'] ?? '').toString();
      String email = '';
      String phone = '';
      if (userId.isNotEmpty) {
        try {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data();
          email = (userData?['email'] ?? '').toString();
          phone = (userData?['contactNumber'] ?? '').toString();
        } catch (_) {}
      }

      try {
        final notification = NotificationService();
        final String who = userName.isNotEmpty ? userName : 'Patient';
        await notification.sendToUser(
          subject: 'Transfer request status update',
          message:
              'Dear $who, your transfer of record request${transferTo.isNotEmpty ? ' to $transferTo' : ''} is now "$newStatus".',
          email: email,
          phone: phone,
          name: who,
        );
        await notification.sendToClinic(
          subject: 'Transfer request updated',
          message:
              '${widget.userName} updated a transfer request${userName.isNotEmpty ? " for $userName" : ''} to "$newStatus".',
        );
      } catch (_) {}

      await AuditLogService.log(
        role: widget.userRole,
        userName: widget.userName,
        action:
            '${widget.userName} updated transfer request${userName.isNotEmpty ? " for $userName" : ''} to "$newStatus"',
        entityType: 'transferRequests',
        entityId: requestId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );

      _fetchTransferRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    List<Map<String, dynamic>> list;
    if (_filterStatus == 'All') {
      list = _requests;
    } else {
      list =
          _requests.where((r) => (r['status'] ?? '') == _filterStatus).toList();
    }

    if (_searchQuery.isEmpty) {
      return list;
    }

    return list.where((r) {
      final String name = (r['userName'] ?? '').toString().toLowerCase();
      final String fullName = (r['fullName'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || fullName.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: primary))
                      : _buildRequestsTable(),
                ),
              ],
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
          _buildMenuItem('DATA GRAPHS', false),
          _buildMenuItem('APPOINTMENT MANAGEMENT', false),
          _buildMenuItem('APPROVE SCHEDULES', false),
          _buildMenuItem('PATIENT RECORDS', false),
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
      case 'PATIENT RECORDS':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPatientRecordsScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
      case 'HISTORY LOGS':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(
              userRole: widget.userRole,
              userName: widget.userName,
              openHistoryLogsOnLoad: true,
            ),
          ),
        );
        break;
      case 'ADD NEW STAFF/NURSE':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(
              userRole: widget.userRole,
              userName: widget.userName,
              openAddStaffOnLoad: true,
            ),
          ),
        );
        break;
      case 'CHANGE PASSWORD':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(
              userRole: widget.userRole,
              userName: widget.userName,
              openChangePasswordOnLoad: true,
            ),
          ),
        );
        break;
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Transfer Record Requests',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Name',
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Regular',
                  color: Colors.grey.shade500,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 20),
          _buildFilterChip('All'),
          const SizedBox(width: 10),
          _buildFilterChip('Pending'),
          const SizedBox(width: 10),
          _buildFilterChip('Processing'),
          const SizedBox(width: 10),
          _buildFilterChip('Completed'),
          const SizedBox(width: 10),
          _buildFilterChip('Rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    bool isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Bold',
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTable() {
    if (_filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'No transfer requests found',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Regular',
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('NO.', flex: 1),
                  _buildHeaderCell('PATIENT NAME', flex: 3),
                  _buildHeaderCell('PATIENT TYPE', flex: 2),
                  _buildHeaderCell('TRANSFER TO', flex: 3),
                  _buildHeaderCell('DATE REQUESTED', flex: 2),
                  _buildHeaderCell('STATUS', flex: 2),
                  _buildHeaderCell('ACTIONS', flex: 2),
                ],
              ),
            ),

            // Table Rows
            ..._filteredRequests.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> request = entry.value;
              return _buildTableRow(
                (index + 1).toString(),
                request['userName'] ?? 'N/A',
                request['patientType'] ?? 'N/A',
                request['transferTo'] ?? 'N/A',
                _formatDate(request['createdAt']),
                request['status'] ?? 'Pending',
                request['id'],
                request,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'Bold',
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableRow(
    String no,
    String patientName,
    String patientType,
    String transferTo,
    String dateRequested,
    String status,
    String requestId,
    Map<String, dynamic> requestData,
  ) {
    Color statusColor;
    if (status == 'Pending') {
      statusColor = Colors.orange;
    } else if (status == 'Processing') {
      statusColor = Colors.blue;
    } else if (status == 'Completed') {
      statusColor = Colors.green;
    } else if (status == 'Rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _buildTableCell(no, flex: 1),
          _buildTableCell(patientName, flex: 3),
          _buildTableCell(patientType, flex: 2),
          _buildTableCell(transferTo, flex: 3),
          _buildTableCell(dateRequested, flex: 2),
          Expanded(
            flex: 2,
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color: statusColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 20),
                  onPressed: () => _showRequestDetails(requestData),
                  tooltip: 'View Details',
                  color: Colors.blue,
                ),
                if (status == 'Pending')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      _updateRequestStatus(requestId, value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'Processing',
                        child: Text('Mark as Processing'),
                      ),
                      const PopupMenuItem(
                        value: 'Completed',
                        child: Text('Mark as Completed'),
                      ),
                      const PopupMenuItem(
                        value: 'Rejected',
                        child: Text('Reject Request'),
                      ),
                    ],
                  ),
                if (status == 'Processing')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      _updateRequestStatus(requestId, value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'Completed',
                        child: Text('Mark as Completed'),
                      ),
                      const PopupMenuItem(
                        value: 'Rejected',
                        child: Text('Reject Request'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
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
          fontSize: 12,
          fontFamily: 'Regular',
          color: Colors.grey.shade700,
        ),
        textAlign: TextAlign.center,
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

  void _showRequestDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Transfer Request Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontFamily: 'Bold',
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem('Patient Name', request['userName']),
                          _buildDetailItem('Full Name', request['fullName']),
                          _buildDetailItem(
                              'Date of Birth', request['dateOfBirth']),
                          _buildDetailItem('Address', request['address']),
                          _buildDetailItem(
                              'Patient Type', request['patientType']),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem(
                              'Transfer To', request['transferTo']),
                          _buildDetailItem(
                              'New Doctor/Clinic', request['newDoctor']),
                          _buildDetailItem(
                              'Clinic Address', request['clinicAddress']),
                          _buildDetailItem(
                              'Contact Info', request['contactInfo']),
                          _buildDetailItem('Reason', request['reason']),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Records Requested:',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (request['recordsRequested']?['laboratoryResults'] ==
                        true)
                      _buildRecordChip('Laboratory Results'),
                    if (request['recordsRequested']?['diagnosticReports'] ==
                        true)
                      _buildRecordChip('Diagnostic Reports'),
                    if (request['recordsRequested']?['vaccinationRecords'] ==
                        true)
                      _buildRecordChip('Vaccination Records'),
                    if (request['recordsRequested']?['clinicalNotes'] == true)
                      _buildRecordChip('Clinical Notes'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailItem('Transfer Method', request['transferMethod']),
                _buildDetailItem('Printed Name', request['printedName']),
                _buildDetailItem('Signature Date', request['signatureDate']),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Bold',
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value ?? 'N/A',
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'Regular',
          color: Colors.blue.shade700,
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
