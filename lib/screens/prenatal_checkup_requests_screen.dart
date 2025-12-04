import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/colors.dart';

class PrenatalCheckupRequestsScreen extends StatefulWidget {
  const PrenatalCheckupRequestsScreen({super.key});

  @override
  State<PrenatalCheckupRequestsScreen> createState() =>
      _PrenatalCheckupRequestsScreenState();
}

class _PrenatalCheckupRequestsScreenState
    extends State<PrenatalCheckupRequestsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _outstandingRequests = [];
  List<Map<String, dynamic>> _pastRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _outstandingRequests = [];
          _pastRequests = [];
        });
        return;
      }

      final snapshot = await _firestore
          .collection('checkupRequests')
          .where('userId', isEqualTo: user.uid)
          .where('patientType', isEqualTo: 'PRENATAL')
          .orderBy('createdAt', descending: true)
          .get();

      final outstanding = <Map<String, dynamic>>[];
      final past = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final status = (data['status'] ?? 'Pending').toString();
        if (status == 'Pending') {
          outstanding.add(data);
        } else {
          past.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _outstandingRequests = outstanding;
          _pastRequests = past;
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

  Future<void> _cancelRequest(String requestId) async {
    try {
      await _firestore.collection('checkupRequests').doc(requestId).update({
        'status': 'Cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Request cancelled successfully',
              style: TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to cancel request',
              style: TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final date = ts.toDate();
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final date = ts.toDate();
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text(
            'View Checkup Requests',
            style: TextStyle(fontFamily: 'Bold'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'OUTSTANDING REQUEST'),
              Tab(text: 'PAST REQUEST'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: primary),
              )
            : TabBarView(
                children: [
                  _buildOutstandingTab(),
                  _buildPastTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOutstandingTab() {
    if (_outstandingRequests.isEmpty) {
      return Center(
        child: Text(
          'No outstanding requests',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Regular',
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: Text('Request ID',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Date Filed',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Preferred Date',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 3,
                      child: Text('Appointment Type',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Status',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Action',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                ],
              ),
            ),
            ..._outstandingRequests
                .map((r) => _buildOutstandingRow(r))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingRow(Map<String, dynamic> request) {
    final id = request['id'] as String? ?? '';
    final shortId = id.length > 8 ? id.substring(id.length - 8) : id;
    final createdAt = request['createdAt'] as Timestamp?;
    final preferredDate = request['preferredDate'] as Timestamp?;
    final status = (request['status'] ?? 'Pending').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(shortId,
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatDateTime(createdAt),
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatDate(preferredDate),
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 3,
            child: Text((request['appointmentType'] ?? '').toString(),
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(status,
                textAlign: TextAlign.center, style: _statusTextStyle(status)),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: ElevatedButton(
                onPressed: status == 'Pending'
                    ? () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              'Cancel Request',
                              style: TextStyle(fontFamily: 'Bold'),
                            ),
                            content: const Text(
                              'Are you sure you want to cancel this request?',
                              style: TextStyle(fontFamily: 'Regular'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  'No',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  'Yes, Cancel',
                                  style: TextStyle(
                                      color: primary, fontFamily: 'Bold'),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _cancelRequest(id);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      status == 'Pending' ? primary : Colors.grey.shade300,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Cancel Request',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Bold',
                    color: status == 'Pending'
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastTab() {
    if (_pastRequests.isEmpty) {
      return Center(
        child: Text(
          'No past requests',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Regular',
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: Text('Request ID',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Date Filed',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Preferred Date',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 3,
                      child: Text('Appointment Type',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 2,
                      child: Text('Status',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                  Expanded(
                      flex: 3,
                      child: Text('Remarks',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontFamily: 'Bold'))),
                ],
              ),
            ),
            ..._pastRequests.map((r) => _buildPastRow(r)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPastRow(Map<String, dynamic> request) {
    final id = request['id'] as String? ?? '';
    final shortId = id.length > 8 ? id.substring(id.length - 8) : id;
    final createdAt = request['createdAt'] as Timestamp?;
    final preferredDate = request['preferredDate'] as Timestamp?;
    final status = (request['status'] ?? 'Pending').toString();
    final remarks = (request['remarks'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(shortId,
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatDateTime(createdAt),
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatDate(preferredDate),
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 3,
            child: Text((request['appointmentType'] ?? '').toString(),
                textAlign: TextAlign.center, style: _rowTextStyle()),
          ),
          Expanded(
            flex: 2,
            child: Text(status,
                textAlign: TextAlign.center, style: _statusTextStyle(status)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              remarks.isEmpty ? '-' : remarks,
              textAlign: TextAlign.center,
              style: _rowTextStyle(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _rowTextStyle() {
    return TextStyle(
      fontSize: 11,
      fontFamily: 'Regular',
      color: Colors.grey.shade800,
    );
  }

  TextStyle _statusTextStyle(String status) {
    Color color;
    switch (status) {
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Approved':
        color = Colors.green;
        break;
      case 'Declined':
        color = Colors.red;
        break;
      case 'Rescheduled':
        color = Colors.blue;
        break;
      case 'Cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey.shade700;
    }
    return TextStyle(
      fontSize: 11,
      fontFamily: 'Bold',
      color: color,
    );
  }
}
