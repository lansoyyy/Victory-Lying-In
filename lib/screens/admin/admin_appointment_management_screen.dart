import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maternity_clinic/services/audit_log_service.dart';
import 'package:maternity_clinic/services/notification_service.dart';

import 'admin_dashboard_screen.dart';
import 'admin_appointment_scheduling_screen.dart';
import 'admin_patient_records_screen.dart';
import 'admin_prenatal_patient_detail_screen.dart';
import 'admin_postnatal_patient_detail_screen.dart';
import '../auth/home_screen.dart';
import '../../utils/colors.dart';

class AdminAppointmentManagementScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const AdminAppointmentManagementScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<AdminAppointmentManagementScreen> createState() =>
      _AdminAppointmentManagementScreenState();
}

class _AdminAppointmentManagementScreenState
    extends State<AdminAppointmentManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _prenatalAppointments = [];
  List<Map<String, dynamic>> _postnatalAppointments = [];
  List<Map<String, dynamic>> _transferRequests = [];
  String _selectedTab = 'prenatal'; // prenatal, postnatal, transfer

  final TextEditingController _prenatalSearchController =
      TextEditingController();
  final TextEditingController _postnatalSearchController =
      TextEditingController();
  final TextEditingController _transferSearchController =
      TextEditingController();

  String _prenatalSearchQuery = '';
  String _postnatalSearchQuery = '';
  String _transferSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();

    _prenatalSearchController.addListener(() {
      setState(() {
        _prenatalSearchQuery =
            _prenatalSearchController.text.trim().toLowerCase();
      });
    });

    _postnatalSearchController.addListener(() {
      setState(() {
        _postnatalSearchQuery =
            _postnatalSearchController.text.trim().toLowerCase();
      });
    });

    _transferSearchController.addListener(() {
      setState(() {
        _transferSearchQuery =
            _transferSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _prenatalSearchController.dispose();
    _postnatalSearchController.dispose();
    _transferSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch users (for joining name/email/patientType)
      final userSnapshot = await _firestore.collection('users').get();
      final Map<String, Map<String, dynamic>> users = {};
      for (var doc in userSnapshot.docs) {
        users[doc.id] = doc.data();
      }

      // Fetch appointments
      final appointmentSnapshot =
          await _firestore.collection('appointments').get();

      List<Map<String, dynamic>> prenatal = [];
      List<Map<String, dynamic>> postnatal = [];

      for (var doc in appointmentSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String status =
            (data['status'] ?? 'Pending').toString().toLowerCase();

        // Only manage PENDING appointments here; accepted will be handled in Approved Schedules
        if (status != 'pending') continue;

        final String userId = (data['userId'] ?? '').toString();
        final userData = users[userId];

        String patientType =
            (userData?['patientType'] ?? data['patientType'] ?? '')
                .toString()
                .toUpperCase();

        final Map<String, dynamic> appt = {
          'id': doc.id,
          'userId': userId,
          'status': status[0].toUpperCase() + status.substring(1),
          'appointmentType': data['appointmentType'] ?? 'Clinic',
          'reason': data['reason'] ?? '',
          'appointmentDate': data['appointmentDate'],
          'createdAt': data['createdAt'],
          'timeSlot': data['timeSlot'],
          'patientType': patientType,
          'patientId': userData?['userId']?.toString() ?? '',
          'name': userData?['name']?.toString() ?? 'Unknown',
          'email': userData?['email']?.toString() ?? '',
          'contactNumber': userData?['contactNumber']?.toString() ?? '',
        };

        if (patientType == 'PRENATAL') {
          prenatal.add(appt);
        } else if (patientType == 'POSTNATAL') {
          postnatal.add(appt);
        }
      }

      prenatal.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs is Timestamp && bTs is Timestamp) {
          return bTs.compareTo(aTs);
        }
        return 0;
      });
      postnatal.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs is Timestamp && bTs is Timestamp) {
          return bTs.compareTo(aTs);
        }
        return 0;
      });

      // Fetch transfer requests
      final transferSnapshot = await _firestore
          .collection('transferRequests')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> transfers = [];
      for (var doc in transferSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? 'Pending').toString();
        if (status == 'Cancelled' || status == 'Rejected') {
          continue;
        }
        data['id'] = doc.id;
        transfers.add(data);
      }

      if (mounted) {
        setState(() {
          _prenatalAppointments = prenatal;
          _postnatalAppointments = postnatal;
          _transferRequests = transfers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPrenatalAppointments {
    if (_prenatalSearchQuery.isEmpty) {
      return _prenatalAppointments;
    }
    return _prenatalAppointments.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      return name.contains(_prenatalSearchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPostnatalAppointments {
    if (_postnatalSearchQuery.isEmpty) {
      return _postnatalAppointments;
    }
    return _postnatalAppointments.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      return name.contains(_postnatalSearchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTransferRequests {
    if (_transferSearchQuery.isEmpty) {
      return _transferRequests;
    }
    return _transferRequests.where((r) {
      final userName = (r['userName'] ?? '').toString().toLowerCase();
      final fullName = (r['fullName'] ?? '').toString().toLowerCase();
      final transferTo = (r['transferTo'] ?? '').toString().toLowerCase();
      return userName.contains(_transferSearchQuery) ||
          fullName.contains(_transferSearchQuery) ||
          transferTo.contains(_transferSearchQuery);
    }).toList();
  }

  Future<void> _acceptAppointment(Map<String, dynamic> appointment) async {
    final String id = appointment['id'] as String? ?? '';
    final String name = appointment['name']?.toString() ?? 'Patient';
    if (id.isEmpty) return;

    try {
      await _firestore.collection('appointments').doc(id).update({
        'status': 'Accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': widget.userName,
      });

      final String email = (appointment['email'] ?? '').toString();
      final String phone = (appointment['contactNumber'] ?? '').toString();
      String dateText = '';
      final dynamic dateField = appointment['appointmentDate'];
      if (dateField is Timestamp) {
        final d = dateField.toDate();
        dateText =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      final String timeSlot = (appointment['timeSlot'] ?? '').toString();

      try {
        final notification = NotificationService();
        await notification.sendToUser(
          subject: 'Your appointment has been accepted',
          message:
              'Dear $name, your appointment on $dateText at $timeSlot has been accepted.\n\nThank you,\nVictory Lying-in Center',
          email: email,
          phone: phone,
          name: name,
        );
        await notification.sendToClinic(
          subject: 'Appointment accepted',
          message:
              '${widget.userName} accepted $name\'s appointment on $dateText at $timeSlot.',
        );
      } catch (_) {}

      await AuditLogService.log(
        role: widget.userRole,
        userName: widget.userName,
        action:
            '${widget.userName} accepted $name\'s appointment on $dateText at $timeSlot',
        entityType: 'appointments',
        entityId: id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment for $name has been accepted',
            style: const TextStyle(fontFamily: 'Regular'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to accept appointment',
            style: TextStyle(fontFamily: 'Regular'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final String id = appointment['id'] as String? ?? '';
    final String name = appointment['name']?.toString() ?? 'Patient';
    if (id.isEmpty) return;

    try {
      await _firestore.collection('appointments').doc(id).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': widget.userName,
      });

      final String email = (appointment['email'] ?? '').toString();
      final String phone = (appointment['contactNumber'] ?? '').toString();
      String dateText = '';
      final dynamic dateField = appointment['appointmentDate'];
      if (dateField is Timestamp) {
        final d = dateField.toDate();
        dateText =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      final String timeSlot = (appointment['timeSlot'] ?? '').toString();

      try {
        final notification = NotificationService();
        await notification.sendToUser(
          subject: 'Your appointment has been cancelled',
          message:
              'Dear $name, your appointment on $dateText at $timeSlot has been cancelled.\n\nIf you have any questions, please contact the clinic.',
          email: email,
          phone: phone,
          name: name,
        );
        await notification.sendToClinic(
          subject: 'Appointment cancelled',
          message:
              '${widget.userName} cancelled $name\'s appointment on $dateText at $timeSlot.',
        );
      } catch (_) {}

      await AuditLogService.log(
        role: widget.userRole,
        userName: widget.userName,
        action:
            '${widget.userName} cancelled $name\'s appointment on $dateText at $timeSlot',
        entityType: 'appointments',
        entityId: id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment for $name has been cancelled',
            style: const TextStyle(fontFamily: 'Regular'),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to cancel appointment',
            style: TextStyle(fontFamily: 'Regular'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateTransferStatus(String requestId, String newStatus) async {
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request status updated to $newStatus'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update transfer request'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openPatientDetail(Map<String, dynamic> appointment) {
    final String patientType =
        appointment['patientType']?.toString().toUpperCase() ?? '';
    final Map<String, String> patientData = {
      'patientId': appointment['patientId']?.toString() ?? '',
      'name': appointment['name']?.toString() ?? '',
      'email': appointment['email']?.toString() ?? '',
      'status': appointment['status']?.toString() ?? '',
      'patientType': patientType,
    };

    if (patientType == 'PRENATAL') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPrenatalPatientDetailScreen(
            patientData: patientData,
          ),
        ),
      );
    } else if (patientType == 'POSTNATAL') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPostnatalPatientDetailScreen(
            patientData: patientData,
          ),
        ),
      );
    }
  }

  void _openTransferPatientDetail(Map<String, dynamic> request) async {
    final String userId = (request['userId'] ?? '').toString();
    if (userId.isEmpty) return;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final String patientType =
          (data['patientType'] ?? '').toString().toUpperCase();

      final Map<String, String> patientData = {
        'patientId': (data['userId'] ?? '').toString(),
        'name': (data['name'] ?? '').toString(),
        'email': (data['email'] ?? '').toString(),
        'status': (data['status'] ?? 'Active').toString(),
        'patientType': patientType,
      };

      if (!mounted) return;
      if (patientType == 'PRENATAL') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPrenatalPatientDetailScreen(
              patientData: patientData,
            ),
          ),
        );
      } else if (patientType == 'POSTNATAL') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPostnatalPatientDetailScreen(
              patientData: patientData,
            ),
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildTabButtons(),
                        const SizedBox(height: 20),
                        if (_selectedTab == 'prenatal')
                          _buildPrenatalSection()
                        else if (_selectedTab == 'postnatal')
                          _buildPostnatalSection()
                        else
                          _buildTransferSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: const [
          Icon(Icons.event_note, size: 28, color: Colors.black87),
          SizedBox(width: 12),
          Text(
            'Appointment Management',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    return Row(
      children: [
        _buildTabButton('Prenatal Appointments', 'prenatal'),
        const SizedBox(width: 10),
        _buildTabButton('Postnatal Appointments', 'postnatal'),
        const SizedBox(width: 10),
        _buildTabButton('Transfer of Record Request', 'transfer'),
      ],
    );
  }

  Widget _buildTabButton(String label, String key) {
    final bool isSelected = _selectedTab == key;
    return ElevatedButton(
      onPressed: isSelected
          ? null
          : () {
              setState(() {
                _selectedTab = key;
              });
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? primary : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: primary, width: 1),
        ),
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'Bold',
        ),
      ),
    );
  }

  Widget _buildPrenatalSection() {
    return _buildAppointmentSection(
      title: 'Prenatal Appointments',
      appointments: _filteredPrenatalAppointments,
      searchController: _prenatalSearchController,
    );
  }

  Widget _buildPostnatalSection() {
    return _buildAppointmentSection(
      title: 'Postnatal Appointments',
      appointments: _filteredPostnatalAppointments,
      searchController: _postnatalSearchController,
    );
  }

  Widget _buildAppointmentSection({
    required String title,
    required List<Map<String, dynamic>> appointments,
    TextEditingController? searchController,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: Colors.black87,
              ),
            ),
          ),
          if (searchController != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: searchController,
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
                ],
              ),
            ),
          if (appointments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No appointments found',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: const [
                  Expanded(
                      flex: 1, child: Text('No.', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('Name', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('Status', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('Appointment Request Date',
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('Action', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 1, child: Text('', textAlign: TextAlign.center)),
                ],
              ),
            ),
            const Divider(height: 1),
            ...appointments.asMap().entries.map((entry) {
              final index = entry.key;
              final appt = entry.value;
              return _buildAppointmentRow(index + 1, appt);
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointmentRow(int index, Map<String, dynamic> appointment) {
    final String status = appointment['status']?.toString() ?? 'Pending';
    final Timestamp? createdAtTs = appointment['createdAt'] as Timestamp?;
    String createdDate = 'N/A';
    if (createdAtTs != null) {
      final d = createdAtTs.toDate();
      createdDate =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    Color statusColor;
    switch (status) {
      case 'Accepted':
        statusColor = Colors.green;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              index.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              appointment['name'] ?? 'Unknown',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              createdDate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _acceptAppointment(appointment),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _cancelAppointment(appointment),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.center,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view') {
                    _openPatientDetail(appointment);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'view',
                    child: Text('View Patient Details & History Checkup'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Transfer of Record Request',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _transferSearchController,
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
              ],
            ),
          ),
          if (_filteredTransferRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No transfer requests found',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: const [
                  Expanded(
                      flex: 1, child: Text('No.', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('Patient Name', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('Patient Type', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('Transfer To', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('Date Request', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('Status', textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('Action', textAlign: TextAlign.center)),
                ],
              ),
            ),
            const Divider(height: 1),
            ..._filteredTransferRequests.asMap().entries.map((entry) {
              final index = entry.key;
              final req = entry.value;
              return _buildTransferRow(index + 1, req);
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferRow(int index, Map<String, dynamic> request) {
    final String status = (request['status'] ?? 'Pending').toString();
    final Timestamp? createdAtTs = request['createdAt'] as Timestamp?;
    String createdDate = 'N/A';
    if (createdAtTs != null) {
      final d = createdAtTs.toDate();
      createdDate =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    Color statusColor;
    switch (status) {
      case 'Processing':
        statusColor = Colors.blue;
        break;
      case 'Completed':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              index.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              request['userName']?.toString() ?? 'N/A',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              request['patientType']?.toString() ?? 'N/A',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              request['transferTo']?.toString() ?? 'N/A',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              createdDate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontFamily: 'Regular'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color: statusColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.description, size: 20),
                  onPressed: () => _showTransferRequestDetails(request),
                  tooltip: 'View Request Form',
                  color: Colors.blue,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'Processing' ||
                        value == 'Completed' ||
                        value == 'Rejected') {
                      _updateTransferStatus(request['id'].toString(), value);
                    } else if (value == 'viewPatient') {
                      _openTransferPatientDetail(request);
                    }
                  },
                  itemBuilder: (context) => [
                    if (status == 'Pending') ...const [
                      PopupMenuItem<String>(
                        value: 'Processing',
                        child: Text('Mark as Processing'),
                      ),
                      PopupMenuItem<String>(
                        value: 'Completed',
                        child: Text('Mark as Completed'),
                      ),
                      PopupMenuItem<String>(
                        value: 'Rejected',
                        child: Text('Reject Request'),
                      ),
                    ] else if (status == 'Processing') ...const [
                      PopupMenuItem<String>(
                        value: 'Completed',
                        child: Text('Mark as Completed'),
                      ),
                      PopupMenuItem<String>(
                        value: 'Rejected',
                        child: Text('Reject Request'),
                      ),
                    ],
                    const PopupMenuItem<String>(
                      value: 'viewPatient',
                      child: Text('View Patient Details & History Checkup'),
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

  void _showTransferRequestDetails(Map<String, dynamic> request) {
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
                          _buildDetailItem(
                              'Patient Name', request['userName'] as String?),
                          _buildDetailItem(
                              'Full Name', request['fullName'] as String?),
                          _buildDetailItem('Date of Birth',
                              request['dateOfBirth'] as String?),
                          _buildDetailItem(
                              'Address', request['address'] as String?),
                          _buildDetailItem('Patient Type',
                              request['patientType'] as String?),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem(
                              'Transfer To', request['transferTo'] as String?),
                          _buildDetailItem('New Doctor/Clinic',
                              request['newDoctor'] as String?),
                          _buildDetailItem('Clinic Address',
                              request['clinicAddress'] as String?),
                          _buildDetailItem('Contact Info',
                              request['contactInfo'] as String?),
                          _buildDetailItem(
                              'Reason', request['reason'] as String?),
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
                _buildDetailItem(
                    'Transfer Method', request['transferMethod'] as String?),
                _buildDetailItem(
                    'Printed Name', request['printedName'] as String?),
                _buildDetailItem(
                    'Signature Date', request['signatureDate'] as String?),
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
          _buildMenuItem('APPOINTMENT MANAGEMENT', true),
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
    Widget screen;
    switch (title) {
      case 'DATA GRAPHS':
        screen = AdminDashboardScreen(
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
      case 'HISTORY LOGS':
        screen = AdminDashboardScreen(
          userRole: widget.userRole,
          userName: widget.userName,
          openHistoryLogsOnLoad: true,
        );
        break;
      case 'ADD NEW STAFF/NURSE':
        screen = AdminDashboardScreen(
          userRole: widget.userRole,
          userName: widget.userName,
          openAddStaffOnLoad: true,
        );
        break;
      case 'CHANGE PASSWORD':
        screen = AdminDashboardScreen(
          userRole: widget.userRole,
          userName: widget.userName,
          openChangePasswordOnLoad: true,
        );
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
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
