import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/colors.dart';
import '../widgets/forgot_password_dialog.dart';
import 'prenatal_dashboard_screen.dart';
import 'prenatal_history_checkup_screen.dart';
import 'notification_appointment_screen.dart';
import 'transfer_record_request_screen.dart';
import 'auth/home_screen.dart';

class PrenatalUpdateProfileScreen extends StatefulWidget {
  const PrenatalUpdateProfileScreen({super.key});

  @override
  State<PrenatalUpdateProfileScreen> createState() =>
      _PrenatalUpdateProfileScreenState();
}

class _PrenatalUpdateProfileScreenState
    extends State<PrenatalUpdateProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  // Basic info
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();

  DateTime? _dob;
  int? _computedAge;

  // Address
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Civil status & emergency contact
  final TextEditingController _civilStatusController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyNumberController =
      TextEditingController();

  final List<String> _civilStatusOptions = const [
    'Single',
    'Married',
    'Live-in Partner',
  ];

  // Pregnancy details
  DateTime? _lmpDate;
  final TextEditingController _gravidaController = TextEditingController();
  final TextEditingController _paraController = TextEditingController();
  final TextEditingController _miscarriagesController = TextEditingController();

  // Derived from LMP (for display only)
  DateTime? _estimatedDueDate;
  int? _gestationalWeeks;

  // Whether profile has already been completed and locked for editing
  bool _isProfileCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _civilStatusController.dispose();
    _emergencyNameController.dispose();
    _emergencyNumberController.dispose();
    _gravidaController.dispose();
    _paraController.dispose();
    _miscarriagesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        _isProfileCompleted = data['profileCompleted'] == true;

        _fullNameController.text = (data['name'] ?? '').toString();
        _emailController.text = (data['email'] ?? user.email ?? '').toString();
        _contactNumberController.text =
            (data['contactNumber'] ?? '').toString();

        if (data['dob'] is Timestamp) {
          _dob = (data['dob'] as Timestamp).toDate();
        }

        _houseNoController.text = (data['addressHouseNo'] ?? '').toString();
        _streetController.text = (data['addressStreet'] ?? '').toString();
        _barangayController.text = (data['addressBarangay'] ?? '').toString();
        _cityController.text = (data['addressCity'] ?? '').toString();

        _civilStatusController.text = (data['civilStatus'] ?? '').toString();
        _emergencyNameController.text =
            (data['emergencyContactName'] ?? '').toString();
        _emergencyNumberController.text =
            (data['emergencyContactNumber'] ?? '').toString();

        if (data['lmpDate'] is Timestamp) {
          _lmpDate = (data['lmpDate'] as Timestamp).toDate();
        }

        _gravidaController.text = data['gravida']?.toString() ?? '';
        _paraController.text = data['para']?.toString() ?? '';
        _miscarriagesController.text = data['miscarriages']?.toString() ?? '';

        _recomputeDerivedValues();
      }
    } catch (_) {
      // On error we just stop loading; UI will show empty fields
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _recomputeDerivedValues() {
    final now = DateTime.now();

    if (_dob != null) {
      int age = now.year - _dob!.year;
      final birthdayThisYear = DateTime(now.year, _dob!.month, _dob!.day);
      if (now.isBefore(birthdayThisYear)) {
        age -= 1;
      }
      _computedAge = age;
    }

    if (_lmpDate != null) {
      _estimatedDueDate = _lmpDate!.add(const Duration(days: 280));
      final days = now.difference(_lmpDate!).inDays;
      if (days >= 0) {
        _gestationalWeeks = days ~/ 7;
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _isProfileCompleted) return;

    if (_fullNameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    if (_contactNumberController.text.trim().isEmpty) {
      _showError('Please enter your contact number');
      return;
    }
    if (_houseNoController.text.trim().isEmpty ||
        _streetController.text.trim().isEmpty ||
        _barangayController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      _showError('Please enter your complete address');
      return;
    }
    if (_civilStatusController.text.trim().isEmpty) {
      _showError('Please enter your civil status');
      return;
    }
    if (_emergencyNameController.text.trim().isEmpty ||
        _emergencyNumberController.text.trim().isEmpty) {
      _showError('Please enter your emergency contact details');
      return;
    }
    if (_lmpDate == null) {
      _showError('Please select your Last Menstrual Period (LMP) date');
      return;
    }
    final gravida = int.tryParse(_gravidaController.text.trim().isEmpty
        ? '0'
        : _gravidaController.text.trim());
    final para = int.tryParse(_paraController.text.trim().isEmpty
        ? '0'
        : _paraController.text.trim());
    final miscarriages = int.tryParse(
        _miscarriagesController.text.trim().isEmpty
            ? '0'
            : _miscarriagesController.text.trim());

    if (gravida == null || para == null || miscarriages == null) {
      _showError('Please enter valid numbers for pregnancy history');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showError('User is not logged in');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      _recomputeDerivedValues();

      final fullAddress = '${_houseNoController.text.trim()}, '
          '${_streetController.text.trim()}, '
          '${_barangayController.text.trim()}, '
          '${_cityController.text.trim()}';

      int? ageToStore = _computedAge;
      if (ageToStore == null && _dob != null) {
        final now = DateTime.now();
        int age = now.year - _dob!.year;
        final birthdayThisYear = DateTime(now.year, _dob!.month, _dob!.day);
        if (now.isBefore(birthdayThisYear)) {
          age -= 1;
        }
        ageToStore = age;
      }

      final Map<String, dynamic> updateData = {
        'name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'addressHouseNo': _houseNoController.text.trim(),
        'addressStreet': _streetController.text.trim(),
        'addressBarangay': _barangayController.text.trim(),
        'addressCity': _cityController.text.trim(),
        'address': fullAddress,
        'civilStatus': _civilStatusController.text.trim(),
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactNumber': _emergencyNumberController.text.trim(),
        'lmpDate': Timestamp.fromDate(_lmpDate!),
        'gravida': gravida,
        'para': para,
        'miscarriages': miscarriages,
        'profileCompleted': true,
      };

      if (_dob != null) {
        updateData['dob'] = Timestamp.fromDate(_dob!);
      }
      if (ageToStore != null) {
        updateData['age'] = ageToStore;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

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
    } catch (e) {
      _showError('Failed to update profile. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Regular'),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primary),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Before you can book an appointment, you need to complete your profile information below.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Regular',
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Once you have saved the required details, they can no longer be edited in the system. Only the clinic information can be changed.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Regular',
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildBasicInfoSection(),
                        const SizedBox(height: 20),
                        _buildRequiredProfileSection(),
                        const SizedBox(height: 20),
                        _buildDerivedInfoSection(),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _isSaving || _isProfileCompleted
                                ? null
                                : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Bold',
                                    ),
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

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Full Name',
            controller: _fullNameController,
            hintText: 'e.g. Maria Dela Cruz',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                  label: 'Age (years)',
                  value:
                      _computedAge?.toString() ?? 'Will be calculated from DOB',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDobPicker(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            label: 'Email Address',
            controller: _emailController,
            hintText: 'e.g. name@example.com',
          ),
          const SizedBox(height: 8),
          _buildTextField(
            label: 'Contact Number',
            controller: _contactNumberController,
            hintText: '11-digit mobile number',
          ),
        ],
      ),
    );
  }

  Widget _buildDobPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth (DOB)',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            if (_isProfileCompleted) return;
            final now = DateTime.now();
            final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(now.year - 60),
              lastDate: now,
            );
            if (picked != null) {
              setState(() {
                _dob = picked;
                _recomputeDerivedValues();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  _dob == null
                      ? 'Select Date of Birth'
                      : '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: _dob == null ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required Profile Information (for booking appointments)',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Complete Address',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'House No.',
                  controller: _houseNoController,
                  hintText: 'House / block / lot number',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  label: 'Street',
                  controller: _streetController,
                  hintText: 'Street name or subdivision',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Barangay',
                  controller: _barangayController,
                  hintText: 'Your barangay',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  label: 'City',
                  controller: _cityController,
                  hintText: 'City or municipality',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Civil Status',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _civilStatusController.text.isEmpty
                ? null
                : _civilStatusController.text,
            items: _civilStatusOptions
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Regular',
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: _isProfileCompleted
                ? null
                : (value) {
                    setState(() {
                      _civilStatusController.text = value ?? '';
                    });
                  },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Emergency Contact',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            label: 'Emergency Contact Name',
            controller: _emergencyNameController,
            hintText: 'e.g. Spouse or close relative',
          ),
          const SizedBox(height: 8),
          _buildTextField(
            label: 'Emergency Contact Number',
            controller: _emergencyNumberController,
            hintText: 'Mobile number of emergency contact',
          ),
          const SizedBox(height: 12),
          const Text(
            'Pregnancy Details',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildLmpPicker(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Number of Previous Pregnancies (Gravida)',
                  controller: _gravidaController,
                  keyboardType: TextInputType.number,
                  hintText: 'Total times you have been pregnant',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  label: 'Number of Living Children (Para)',
                  controller: _paraController,
                  keyboardType: TextInputType.number,
                  hintText: 'Number of live births',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            label: 'Number of Miscarriages / Abortions',
            controller: _miscarriagesController,
            keyboardType: TextInputType.number,
            hintText: 'Number of previous miscarriages / abortions',
          ),
        ],
      ),
    );
  }

  Widget _buildLmpPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last Menstrual Period (LMP)',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            if (_isProfileCompleted) return;
            final now = DateTime.now();
            final initial = _lmpDate ?? now.subtract(const Duration(days: 28));
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: now.subtract(const Duration(days: 280)),
              lastDate: now,
            );
            if (picked != null) {
              setState(() {
                _lmpDate = picked;
                _recomputeDerivedValues();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  _lmpDate == null
                      ? 'Select LMP Date'
                      : '${_lmpDate!.month.toString().padLeft(2, '0')}/${_lmpDate!.day.toString().padLeft(2, '0')}/${_lmpDate!.year}',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Regular',
                    color: _lmpDate == null
                        ? Colors.grey.shade600
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDerivedInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Calculations (based on LMP)',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildReadOnlyField(
            label: 'Estimated Due Date (EDD)',
            value: _estimatedDueDate == null
                ? 'Will be calculated after you set LMP'
                : '${_estimatedDueDate!.month.toString().padLeft(2, '0')}/${_estimatedDueDate!.day.toString().padLeft(2, '0')}/${_estimatedDueDate!.year}',
          ),
          const SizedBox(height: 12),
          _buildReadOnlyField(
            label: 'Age of Gestation (weeks)',
            value: _gestationalWeeks == null
                ? 'Will be calculated after you set LMP'
                : '${_gestationalWeeks.toString()} weeks',
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: !_isProfileCompleted,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: Colors.grey.shade500,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
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
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
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
              children: const [
                Text(
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
          _buildMenuItem('PERSONAL DETAILS', true),
          _buildMenuItem('EDUCATIONAL\nLEARNERS', false),
          _buildMenuItem('HISTORY OF\nCHECK UP', false),
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

          if (isActive) {
            return;
          }

          if (title == 'EDUCATIONAL\nLEARNERS') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const PrenatalDashboardScreen(),
              ),
            );
          } else if (title == 'HISTORY OF\nCHECK UP') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const PrenatalHistoryCheckupScreen(),
              ),
            );
          } else if (title == 'REQUEST &\nNOTIFICATION APPOINTMENT') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationAppointmentScreen(
                  patientType: 'PRENATAL',
                ),
              ),
            );
          } else if (title == 'TRANSFER OF\nRECORD REQUEST') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TransferRecordRequestScreen(
                  patientType: 'PRENATAL',
                ),
              ),
            );
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
