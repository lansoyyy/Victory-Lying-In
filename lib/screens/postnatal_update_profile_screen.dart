import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/colors.dart';
import '../widgets/forgot_password_dialog.dart';
import 'postnatal_dashboard_screen.dart';
import 'postnatal_history_checkup_screen.dart';
import 'notification_appointment_screen.dart';
import 'transfer_record_request_screen.dart';
import 'auth/home_screen.dart';

class PostnatalUpdateProfileScreen extends StatefulWidget {
  const PostnatalUpdateProfileScreen({super.key});

  @override
  State<PostnatalUpdateProfileScreen> createState() =>
      _PostnatalUpdateProfileScreenState();
}

class _PostnatalUpdateProfileScreenState
    extends State<PostnatalUpdateProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProfileCompleted = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();

  DateTime? _dob;
  int? _computedAge;

  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  final TextEditingController _civilStatusController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyNumberController =
      TextEditingController();

  DateTime? _deliveryDate;
  String? _deliveryPlace;
  String? _deliveryType;

  final TextEditingController _infantNameController = TextEditingController();
  final TextEditingController _infantAgeController = TextEditingController();
  final TextEditingController _infantBirthWeightController =
      TextEditingController();
  String? _infantGender;

  bool _excessiveBleeding = false;
  bool _fever = false;
  bool _pain = false;
  bool _breastfeedingDifficulty = false;
  bool _woundInfection = false;
  final TextEditingController _otherConcernsController =
      TextEditingController();

  String? _bp;
  String? _temperature;
  String? _pulse;
  String? _fundalHeight;
  String? _lochiaStatus;
  String? _riskStatus;
  String? _specificComplication;

  final List<String> _civilStatusOptions = const [
    'Single',
    'Married',
    'Live-in Partner',
  ];

  final List<String> _deliveryPlaces = const [
    'Home',
    'Lying-in',
    'Hospital',
  ];

  final List<String> _deliveryTypes = const [
    'Normal Spontaneous Delivery (NSD)',
    'Cesarean Section',
    'Assisted Delivery (Forceps/Vacuum)',
  ];

  final List<String> _lochiaOptions = const [
    'Scant',
    'Moderate',
    'Heavy',
  ];

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
    _infantNameController.dispose();
    _infantAgeController.dispose();
    _infantBirthWeightController.dispose();
    _otherConcernsController.dispose();
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

        if (data['dateOfDelivery'] is Timestamp) {
          _deliveryDate = (data['dateOfDelivery'] as Timestamp).toDate();
        }
        _deliveryPlace = data['placeOfDelivery']?.toString();
        _deliveryType = data['deliveryType']?.toString();

        _excessiveBleeding = data['postnatalExcessiveBleeding'] == true;
        _fever = data['postnatalFever'] == true;
        _pain = data['postnatalPain'] == true;
        _breastfeedingDifficulty = data['breastfeedingDifficulty'] == true;
        _woundInfection = data['woundInfectionSigns'] == true;
        _otherConcernsController.text =
            (data['otherPostnatalConcerns'] ?? '').toString();

        _bp = data['postnatalBloodPressure']?.toString();
        _temperature = data['postnatalTemperature']?.toString();
        _pulse = data['postnatalPulse']?.toString();
        _fundalHeight = data['fundalHeight']?.toString();
        _lochiaStatus = data['lochiaStatus']?.toString();
        _riskStatus = data['riskStatus']?.toString();
        _specificComplication = data['specificComplication']?.toString();

        _infantNameController.text = (data['infantName'] ?? '').toString();
        _infantGender = data['infantGender']?.toString();
        _infantAgeController.text = (data['infantAge'] ?? '').toString();
        _infantBirthWeightController.text =
            (data['infantBirthWeight'] ?? '').toString();

        _recomputeAge();
      }
    } catch (_) {
      // Ignore, just show empty form
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _recomputeAge() {
    if (_dob == null) {
      _computedAge = null;
      return;
    }
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    final birthdayThisYear = DateTime(now.year, _dob!.month, _dob!.day);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }
    _computedAge = age;
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    final birthdayThisYear = DateTime(now.year, dob.month, dob.day);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }
    return age;
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
    if (_deliveryDate == null) {
      _showError('Please select delivery date');
      return;
    }
    if (_deliveryPlace == null || _deliveryPlace!.trim().isEmpty) {
      _showError('Please select place of delivery');
      return;
    }
    if (_deliveryType == null || _deliveryType!.trim().isEmpty) {
      _showError('Please select type of delivery');
      return;
    }

    if (_infantNameController.text.trim().isEmpty) {
      _showError('Please enter infant\'s name');
      return;
    }
    if (_infantGender == null || _infantGender!.trim().isEmpty) {
      _showError('Please select infant\'s gender');
      return;
    }
    if (_infantAgeController.text.trim().isEmpty) {
      _showError('Please enter current age of infant');
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
      if (_dob != null) {
        _computedAge = _calculateAge(_dob!);
      }

      final fullAddress = '${_houseNoController.text.trim()}, '
          '${_streetController.text.trim()}, '
          '${_barangayController.text.trim()}, '
          '${_cityController.text.trim()}';

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
        'dateOfDelivery': Timestamp.fromDate(_deliveryDate!),
        'placeOfDelivery': _deliveryPlace,
        'deliveryType': _deliveryType,
        'infantName': _infantNameController.text.trim(),
        'infantGender': _infantGender,
        'infantAge': _infantAgeController.text.trim(),
        'infantBirthWeight': _infantBirthWeightController.text.trim(),
        'profileCompleted': true,
      };

      if (_dob != null) {
        updateData['dob'] = Timestamp.fromDate(_dob!);
      }
      if (_computedAge != null) {
        updateData['age'] = _computedAge;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

      if (mounted) {
        setState(() {
          _isProfileCompleted = true;
        });
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
    } catch (_) {
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
                          padding: const EdgeInsets.all(16),
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
                                  fontSize: 13,
                                  fontFamily: 'Regular',
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildRequiredProfileSection(),
                        const SizedBox(height: 24),
                        _buildDeliveryDetailsSection(),
                        const SizedBox(height: 24),
                        _buildInfantInfoSection(),
                        const SizedBox(height: 32),
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
                  'POSTNATAL PATIENT',
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
                builder: (context) => const PostnatalDashboardScreen(),
              ),
            );
          } else if (title == 'HISTORY OF\nCHECK UP') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const PostnatalHistoryCheckupScreen(),
              ),
            );
          } else if (title == 'REQUEST &\nNOTIFICATION APPOINTMENT') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationAppointmentScreen(
                  patientType: 'POSTNATAL',
                ),
              ),
            );
          } else if (title == 'TRANSFER OF\nRECORD REQUEST') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TransferRecordRequestScreen(
                  patientType: 'POSTNATAL',
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

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Full Name',
            controller: _fullNameController,
            hintText: 'e.g. Maria Dela Cruz',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                  label: 'Age (years)',
                  value:
                      _computedAge?.toString() ?? 'Will be calculated from DOB',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDobPicker(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Email Address',
            controller: _emailController,
            hintText: 'e.g. name@example.com',
          ),
          const SizedBox(height: 12),
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
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
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
                _recomputeAge();
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
                  _dob == null
                      ? 'Select Date of Birth'
                      : '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}',
                  style: TextStyle(
                    fontSize: 13,
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
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          const Text(
            'Civil Status',
            style: TextStyle(
              fontSize: 13,
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
          const SizedBox(height: 16),
          const Text(
            'Emergency Contact',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            label: 'Emergency Contact Name',
            controller: _emergencyNameController,
            hintText: 'e.g. Spouse or close relative',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Emergency Contact Number',
            controller: _emergencyNumberController,
            hintText: 'Mobile number of emergency contact',
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Details',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Delivery Date',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              if (_isProfileCompleted) return;
              final now = DateTime.now();
              final initial = _deliveryDate ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now,
              );
              if (picked != null) {
                setState(() {
                  _deliveryDate = picked;
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
                    _deliveryDate == null
                        ? 'Select delivery date'
                        : '${_deliveryDate!.month.toString().padLeft(2, '0')}/${_deliveryDate!.day.toString().padLeft(2, '0')}/${_deliveryDate!.year}',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Regular',
                      color: _deliveryDate == null
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Place of Delivery',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _deliveryPlace,
            items: _deliveryPlaces
                .map(
                  (place) => DropdownMenuItem(
                    value: place,
                    child: Text(
                      place,
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
                      _deliveryPlace = value;
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
          const SizedBox(height: 16),
          const Text(
            'Type of Delivery',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _deliveryType,
            items: _deliveryTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type,
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
                      _deliveryType = value;
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
        ],
      ),
    );
  }

  Widget _buildInfantInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Infant Information',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Infant Name',
            controller: _infantNameController,
            hintText: 'e.g. Baby\'s full name',
          ),
          const SizedBox(height: 12),
          const Text(
            'Infant\'s Gender',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _infantGender,
            items: const ['Female', 'Male']
                .map(
                  (gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ),
                )
                .toList(),
            onChanged: _isProfileCompleted
                ? null
                : (value) {
                    setState(() {
                      _infantGender = value;
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
          _buildTextField(
            label: 'Current Age of Infant',
            controller: _infantAgeController,
            hintText: 'e.g. 2 weeks, 6 weeks',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Birth Weight (kg)',
            controller: _infantBirthWeightController,
            keyboardType: TextInputType.number,
            hintText: 'e.g. 3.2',
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalViewOnlySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clinical Information (updated by staff/admin)',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildReadOnlyField(
            label: 'Risk Level',
            value: _riskStatus ?? 'Not yet recorded',
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            label: 'Specific Complication',
            value: _specificComplication ?? 'Not yet recorded',
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            label: 'Blood Pressure',
            value: _bp ?? 'Not yet recorded',
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            label: 'Temperature',
            value: _temperature ?? 'Not yet recorded',
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            label: 'Pulse',
            value: _pulse ?? 'Not yet recorded',
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            label: 'Fundal Height',
            value: _fundalHeight ?? 'Not yet recorded',
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            label: 'Lochia Status',
            value: _lochiaStatus ?? 'Not yet recorded',
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
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: !_isProfileCompleted,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontFamily: 'Regular',
              fontSize: 12,
            ),
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
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
