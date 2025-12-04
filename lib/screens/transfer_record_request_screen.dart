import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';
import '../widgets/forgot_password_dialog.dart';
import 'prenatal_dashboard_screen.dart';
import 'postnatal_dashboard_screen.dart';
import 'prenatal_history_checkup_screen.dart';
import 'postnatal_history_checkup_screen.dart';
import 'notification_appointment_screen.dart';
import 'auth/home_screen.dart';

class TransferRecordRequestScreen extends StatefulWidget {
  final String patientType; // 'PRENATAL' or 'POSTNATAL'

  const TransferRecordRequestScreen({
    super.key,
    required this.patientType,
  });

  @override
  State<TransferRecordRequestScreen> createState() =>
      _TransferRecordRequestScreenState();
}

class _TransferRecordRequestScreenState
    extends State<TransferRecordRequestScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = 'Loading...';
  bool _hasExistingRequest = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _existingRequest;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _transferToController = TextEditingController();
  final TextEditingController _newDoctorController = TextEditingController();
  final TextEditingController _clinicAddressController =
      TextEditingController();
  final TextEditingController _contactInfoController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _printedNameController = TextEditingController();
  final TextEditingController _signatureDateController =
      TextEditingController();

  bool _laboratoryResults = false;
  bool _diagnosticReports = false;
  bool _vaccinationRecords = false;
  bool _clinicalNotes = false;

  String _transferMethod = 'Pick-up by Patient/Authorized Representative';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkExistingRequest();
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

  Future<void> _cancelExistingRequest() async {
    final String? id = _existingRequest?['id'] as String?;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cancel Transfer Request',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: const Text(
          'Are you sure you want to cancel this transfer of record request?',
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
      await _firestore.collection('transferRequests').doc(id).update({
        'status': 'Cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'patient',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Transfer request cancelled successfully',
            style: TextStyle(fontFamily: 'Regular'),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _checkExistingRequest();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to cancel transfer request. Please try again.',
            style: TextStyle(fontFamily: 'Regular'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkExistingRequest() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot requestSnapshot = await _firestore
            .collection('transferRequests')
            .where('userId', isEqualTo: user.uid)
            .where('status', whereIn: ['Pending', 'Processing']).get();

        if (mounted) {
          setState(() {
            _hasExistingRequest = requestSnapshot.docs.isNotEmpty;
            if (_hasExistingRequest) {
              _existingRequest =
                  requestSnapshot.docs.first.data() as Map<String, dynamic>;
              _existingRequest!['id'] = requestSnapshot.docs.first.id;
            }
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
    }
  }

  Future<void> _submitRequest() async {
    if (_fullNameController.text.trim().isEmpty ||
        _dateOfBirthController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _transferToController.text.trim().isEmpty ||
        _printedNameController.text.trim().isEmpty ||
        _signatureDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> requestData = {
          'userId': user.uid,
          'userName': _userName,
          'patientType': widget.patientType,
          'fullName': _fullNameController.text.trim(),
          'dateOfBirth': _dateOfBirthController.text.trim(),
          'address': _addressController.text.trim(),
          'otherContact': _otherController.text.trim(),
          'transferTo': _transferToController.text.trim(),
          'newDoctor': _newDoctorController.text.trim(),
          'clinicAddress': _clinicAddressController.text.trim(),
          'contactInfo': _contactInfoController.text.trim(),
          'reason': _reasonController.text.trim(),
          'recordsRequested': {
            'laboratoryResults': _laboratoryResults,
            'diagnosticReports': _diagnosticReports,
            'vaccinationRecords': _vaccinationRecords,
            'clinicalNotes': _clinicalNotes,
          },
          'transferMethod': _transferMethod,
          'printedName': _printedNameController.text.trim(),
          'signatureDate': _signatureDateController.text.trim(),
          'status': 'Pending',
        };

        // Update existing request or create new one
        if (_existingRequest != null && _existingRequest!['id'] != null) {
          await _firestore
              .collection('transferRequests')
              .doc(_existingRequest!['id'])
              .update(requestData);
        } else {
          requestData['createdAt'] = FieldValue.serverTimestamp();
          await _firestore.collection('transferRequests').add(requestData);
        }

        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_existingRequest != null
                  ? 'Transfer request updated successfully!'
                  : 'Transfer request submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _checkExistingRequest();
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _otherController.dispose();
    _transferToController.dispose();
    _newDoctorController.dispose();
    _clinicAddressController.dispose();
    _contactInfoController.dispose();
    _reasonController.dispose();
    _printedNameController.dispose();
    _signatureDateController.dispose();
    super.dispose();
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
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _hasExistingRequest
                    ? _buildExistingRequestView()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'TRANSFER OF RECORD REQUEST',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Bold',
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Form Content
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column
                                Expanded(
                                  child: _buildLeftColumn(),
                                ),
                                const SizedBox(width: 60),

                                // Right Column
                                Expanded(
                                  child: _buildRightColumn(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingRequestView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // ... rest of the code remains the same ...
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_circle,
                    size: 40, color: Colors.green.shade700),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transfer Request Submitted',
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Bold',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Your request is being processed',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _existingRequest?['status'] == 'Pending'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _existingRequest?['status'] ?? 'Pending',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Bold',
                        color: _existingRequest?['status'] == 'Pending'
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  if ((_existingRequest?['status'] ?? 'Pending') == 'Pending')
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'cancel') {
                          _cancelExistingRequest();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'cancel',
                          child: Text('Cancel request'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Request Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      'Personal Information',
                      Icons.person,
                      [
                        _buildDetailRow(
                            'Full Name', _existingRequest?['fullName']),
                        _buildDetailRow(
                            'Date of Birth', _existingRequest?['dateOfBirth']),
                        _buildDetailRow(
                            'Address', _existingRequest?['address']),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _buildDetailSection(
                      'Records Requested',
                      Icons.folder_copy,
                      [
                        _buildCheckRow(
                            'Laboratory Results',
                            _existingRequest?['recordsRequested']
                                    ?['laboratoryResults'] ??
                                false),
                        _buildCheckRow(
                            'Diagnostic Reports',
                            _existingRequest?['recordsRequested']
                                    ?['diagnosticReports'] ??
                                false),
                        _buildCheckRow(
                            'Vaccination Records',
                            _existingRequest?['recordsRequested']
                                    ?['vaccinationRecords'] ??
                                false),
                        _buildCheckRow(
                            'Clinical Notes',
                            _existingRequest?['recordsRequested']
                                    ?['clinicalNotes'] ??
                                false),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),

              // Right Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      'Transfer Information',
                      Icons.local_hospital,
                      [
                        _buildDetailRow(
                            'Transfer To', _existingRequest?['transferTo']),
                        _buildDetailRow('New Doctor/Clinic',
                            _existingRequest?['newDoctor']),
                        _buildDetailRow('Clinic Address',
                            _existingRequest?['clinicAddress']),
                        _buildDetailRow(
                            'Contact Info', _existingRequest?['contactInfo']),
                        _buildDetailRow('Reason', _existingRequest?['reason']),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _buildDetailSection(
                      'Transfer Method',
                      Icons.send,
                      [
                        _buildDetailRow(
                            'Method', _existingRequest?['transferMethod']),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Edit Button
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasExistingRequest = false;
                  _loadFormData();
                });
              },
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text(
                'Edit Request',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
      String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          const SizedBox(height: 4),
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

  Widget _buildCheckRow(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: checked ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _loadFormData() {
    if (_existingRequest != null) {
      _fullNameController.text = _existingRequest!['fullName'] ?? '';
      _dateOfBirthController.text = _existingRequest!['dateOfBirth'] ?? '';
      _addressController.text = _existingRequest!['address'] ?? '';
      _otherController.text = _existingRequest!['otherContact'] ?? '';
      _transferToController.text = _existingRequest!['transferTo'] ?? '';
      _newDoctorController.text = _existingRequest!['newDoctor'] ?? '';
      _clinicAddressController.text = _existingRequest!['clinicAddress'] ?? '';
      _contactInfoController.text = _existingRequest!['contactInfo'] ?? '';
      _reasonController.text = _existingRequest!['reason'] ?? '';
      _printedNameController.text = _existingRequest!['printedName'] ?? '';
      _signatureDateController.text = _existingRequest!['signatureDate'] ?? '';

      setState(() {
        _laboratoryResults = _existingRequest!['recordsRequested']
                ?['laboratoryResults'] ??
            false;
        _diagnosticReports = _existingRequest!['recordsRequested']
                ?['diagnosticReports'] ??
            false;
        _vaccinationRecords = _existingRequest!['recordsRequested']
                ?['vaccinationRecords'] ??
            false;
        _clinicalNotes =
            _existingRequest!['recordsRequested']?['clinicalNotes'] ?? false;
        _transferMethod = _existingRequest!['transferMethod'] ??
            'Pick-up by Patient/Authorized Representative';
      });
    }
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
          _buildMenuItem('REQUEST &\nNOTIFICATION APPOINTMENT', false),
          _buildMenuItem('TRANSFER OF\nRECORD REQUEST', true),

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => NotificationAppointmentScreen(
                  patientType: widget.patientType)),
        );
        break;
      case 'TRANSFER OF\nRECORD REQUEST':
        // Already on this screen
        break;
    }
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Full Name:', _fullNameController),
        const SizedBox(height: 15),
        _buildDateOfBirthField(),
        const SizedBox(height: 15),
        _buildTextField('Address:', _addressController),
        const SizedBox(height: 25),

        // Records to Transfer
        const Text(
          'Medical History',
          style: TextStyle(
              fontSize: 14, fontFamily: 'Regular', color: Colors.black87),
        ),
        const SizedBox(height: 10),
        _buildCheckbox('Laboratory Results', _laboratoryResults, (value) {
          setState(() => _laboratoryResults = value!);
        }),
        _buildCheckbox('Diagnostic Reports', _diagnosticReports, (value) {
          setState(() => _diagnosticReports = value!);
        }),
        _buildCheckbox('Vaccination Records', _vaccinationRecords, (value) {
          setState(() => _vaccinationRecords = value!);
        }),
        _buildCheckbox('Clinical Notes', _clinicalNotes, (value) {
          setState(() => _clinicalNotes = value!);
        }),
        const SizedBox(height: 15),
        _buildTextField('Other (Please specify):', _otherController),
        const SizedBox(height: 25),

        // Transfer Information
        _buildTextField(
            'Transfer To (New Clinic/Physician):', _transferToController),
        const SizedBox(height: 15),
        _buildTextField('Name of New Doctor/Clinic:', _newDoctorController),
        const SizedBox(height: 15),
        _buildTextField('Clinic Address:', _clinicAddressController),
        const SizedBox(height: 15),
        _buildTextField('Contact Information:', _contactInfoController),
        const SizedBox(height: 15),
        _buildTextField('Reason for Transfer:', _reasonController),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Method of Transfer:',
          style: TextStyle(
              fontSize: 14, fontFamily: 'Bold', color: Colors.black87),
        ),
        const SizedBox(height: 10),
        _buildRadioOption('Pick-up by Patient/Authorized Representative'),
        const SizedBox(height: 30),

        const Text(
          'Patient/ Legal Guardian:',
          style: TextStyle(
              fontSize: 14, fontFamily: 'Bold', color: Colors.black87),
        ),
        const SizedBox(height: 10),
        _buildTextField('Printed Name:', _printedNameController),
        const SizedBox(height: 15),
        _buildSignatureDateField(),
        const SizedBox(height: 40),

        // Submit Button
        Center(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateOfBirthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth:',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            DateTime initial = DateTime(now.year - 25, now.month, now.day);
            final existing = _dateOfBirthController.text.trim();
            final parsedExisting =
                existing.isNotEmpty ? DateTime.tryParse(existing) : null;
            if (parsedExisting != null && parsedExisting.isBefore(now)) {
              initial = parsedExisting;
            }

            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(now.year - 100),
              lastDate: now,
            );
            if (picked != null) {
              setState(() {
                _dateOfBirthController.text =
                    '${picked.month}/${picked.day}/${picked.year}';
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  _dateOfBirthController.text.isNotEmpty
                      ? _dateOfBirthController.text
                      : 'Select Date of Birth',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Regular',
                    color: _dateOfBirthController.text.isNotEmpty
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date:',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            DateTime initial = now;
            final existing = _signatureDateController.text.trim();
            final parsedExisting =
                existing.isNotEmpty ? DateTime.tryParse(existing) : null;
            if (parsedExisting != null && !parsedExisting.isBefore(now)) {
              initial = parsedExisting;
            }

            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _signatureDateController.text =
                    '${picked.month}/${picked.day}/${picked.year}';
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  _signatureDateController.text.isNotEmpty
                      ? _signatureDateController.text
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Regular',
                    color: _signatureDateController.text.isNotEmpty
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontSize: 13, fontFamily: 'Regular'),
        ),
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String option) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Radio<String>(
            value: option,
            groupValue: _transferMethod,
            onChanged: (value) {
              setState(() {
                _transferMethod = value!;
              });
            },
            activeColor: primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            option,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
        ),
      ],
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
