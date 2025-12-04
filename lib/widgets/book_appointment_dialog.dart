import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookAppointmentDialog extends StatefulWidget {
  final String patientType; // 'PRENATAL' or 'POSTNATAL'

  const BookAppointmentDialog({
    super.key,
    required this.patientType,
  });

  @override
  State<BookAppointmentDialog> createState() => _BookAppointmentDialogState();
}

class _BookAppointmentDialogState extends State<BookAppointmentDialog> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Common fields
  final TextEditingController _fullNameController = TextEditingController();
  String? _selectedAppointmentType;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;

  // Prenatal specific fields
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _lmpDate;
  final TextEditingController _ageController = TextEditingController();
  bool _firstPregnancy = true;
  final TextEditingController _pregnancyCountController =
      TextEditingController(text: '1');
  bool _highBloodPressure = false;
  bool _diabetes = false;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bloodPressureController =
      TextEditingController();

  // Postnatal specific fields
  DateTime? _deliveryDate;
  String? _deliveryType;
  final TextEditingController _infantNameController = TextEditingController();
  String? _infantGender;
  final TextEditingController _infantAgeController = TextEditingController();
  bool _incisionConcern = false;
  bool _heavyBleeding = false;
  bool _depressed = false;
  bool _noPleasure = false;
  String? _feedingMethod;
  bool _feedingConcern = false;
  bool _infantFever = false;
  bool _fewDiapers = false;

  // Union of all possible time slots; actual availability depends on selected day
  // and appointment type (e.g., prenatal Ultrasound has special rules).
  final List<String> _timeSlots = [
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
    '6:00 PM',
  ];

  final List<String> _prenatalAppointmentTypes = [
    'Initial/first visit',
    'Checkup',
    'Followup checkup',
    'Ultrasound'
  ];

  final List<String> _postnatalAppointmentTypes = [
    'Routine Postnatal Checkup',
    '2-week Infant Check',
    '6-week Mother & Infant Check'
  ];

  final List<String> _deliveryTypes = [
    'Vaginal',
    'C-Section',
    'Assisted',
    'Forceps',
    'Vacuum'
  ];

  final List<String> _feedingMethods = ['Breastfeeding', 'Formula', 'Mixed'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _fullNameController.text = userData['name'] ?? '';
            _ageController.text = userData['age']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<int> _getAppointmentCountForTimeSlot(
      DateTime date, String timeSlot) async {
    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('appointmentDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('timeSlot', isEqualTo: timeSlot)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting appointment count: $e');
      return 0;
    }
  }

  Future<void> _bookAppointment() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Check if time slot is still available
      int currentCount = await _getAppointmentCountForTimeSlot(
          _selectedDate!, _selectedTimeSlot!);
      if (currentCount >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This time slot is no longer available. Please select another time.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> appointmentData = {
        'userId': user.uid,
        'fullName': _fullNameController.text.trim(),
        'appointmentType': _selectedAppointmentType,
        'appointmentDate': Timestamp.fromDate(_selectedDate!),
        'timeSlot': _selectedTimeSlot,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.patientType == 'POSTNATAL') {
        appointmentData.addAll({
          'deliveryDate':
              _deliveryDate != null ? Timestamp.fromDate(_deliveryDate!) : null,
          'deliveryType': _deliveryType,
          'infantName': _infantNameController.text.trim(),
          'infantGender': _infantGender,
          'infantAge': _infantAgeController.text.trim(),
          'incisionConcern': _incisionConcern,
          'heavyBleeding': _heavyBleeding,
          'depressed': _depressed,
          'noPleasure': _noPleasure,
          'feedingMethod': _feedingMethod,
          'feedingConcern': _feedingConcern,
          'infantFever': _infantFever,
          'fewDiapers': _fewDiapers,
          'bloodPressure': _bloodPressureController.text.trim(),
          'weight': _weightController.text.trim(),
        });
      }

      await _firestore.collection('appointments').add(appointmentData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (_fullNameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return false;
    }
    if (_selectedAppointmentType == null) {
      _showError('Please select appointment type');
      return false;
    }
    if (_selectedDate == null) {
      _showError('Please select appointment date');
      return false;
    }
    if (_selectedTimeSlot == null) {
      _showError('Please select time slot');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF50C2C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book Appointment',
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'Bold',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.patientType} Patient',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommonFields(),
                    const SizedBox(height: 20),
                    _buildDateTimeFields(),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontFamily: 'Regular',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _bookAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Book Appointment',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Bold',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Name
        const Text(
          'Full Name',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fullNameController,
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Appointment Type
        const Text(
          'Appointment Type',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedAppointmentType,
          decoration: InputDecoration(
            hintText: 'Select appointment type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
          items: (widget.patientType == 'PRENATAL'
                  ? _prenatalAppointmentTypes
                  : _postnatalAppointmentTypes)
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAppointmentType = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPrenatalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prenatal Information',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: Color(0xFF4A90E2),
          ),
        ),
        const SizedBox(height: 15),

        // Reason for Visit
        const Text(
          'Briefly describe the main reason for your visit today',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          decoration: InputDecoration(
            hintText:
                'e.g., Routine checkup, Abnormal spotting, First time seeing a doctor for this pregnancy',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 15),

        // LMP Date
        const Text(
          'What was the exact date of the first day of your last menstrual period (LMP)?',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 28)),
              firstDate: DateTime.now().subtract(const Duration(days: 280)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _lmpDate = picked;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                const SizedBox(width: 10),
                Text(
                  _lmpDate != null ? _formatDate(_lmpDate!) : 'Select LMP Date',
                  style: TextStyle(
                    color: _lmpDate != null ? Colors.black87 : Colors.grey,
                    fontFamily: 'Regular',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Age
        const Text(
          'How old are you?',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter your age',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // First Pregnancy
        const Text(
          'Is this your first time being pregnant?',
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
              child: RadioListTile<bool>(
                title: const Text('Yes'),
                value: true,
                groupValue: _firstPregnancy,
                onChanged: (value) {
                  setState(() {
                    _firstPregnancy = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('No'),
                value: false,
                groupValue: _firstPregnancy,
                onChanged: (value) {
                  setState(() {
                    _firstPregnancy = value!;
                  });
                },
              ),
            ),
          ],
        ),
        if (!_firstPregnancy) ...[
          const SizedBox(height: 10),
          const Text(
            'How many times have you been pregnant in total (including this one)?',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pregnancyCountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter total pregnancy count',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFF4A90E2)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 15),

        // Medical Conditions
        const Text(
          'Medical Conditions',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          title: const Text(
              'Are you currently taking medication for High Blood Pressure?'),
          value: _highBloodPressure,
          onChanged: (value) {
            setState(() {
              _highBloodPressure = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Have you been diagnosed with diabetes (Sugar)?'),
          value: _diabetes,
          onChanged: (value) {
            setState(() {
              _diabetes = value!;
            });
          },
        ),
        const SizedBox(height: 15),

        // Current Weight and Blood Pressure
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Weight',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Bold',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      hintText: 'kg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Blood Pressure',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Bold',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bloodPressureController,
                    decoration: InputDecoration(
                      hintText: 'mmHg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostnatalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Postnatal Information',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: Color(0xFF4A90E2),
          ),
        ),
        const SizedBox(height: 15),

        // Delivery Date
        const Text(
          'Date of Delivery',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 7)),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _deliveryDate = picked;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                const SizedBox(width: 10),
                Text(
                  _deliveryDate != null
                      ? _formatDate(_deliveryDate!)
                      : 'Select Delivery Date',
                  style: TextStyle(
                    color: _deliveryDate != null ? Colors.black87 : Colors.grey,
                    fontFamily: 'Regular',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Delivery Type
        const Text(
          'Type of Delivery',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _deliveryType,
          decoration: InputDecoration(
            hintText: 'Select delivery type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
          items: _deliveryTypes
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _deliveryType = value;
            });
          },
        ),
        const SizedBox(height: 15),

        // Infant Information
        const Text(
          'Infant Information',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _infantNameController,
          decoration: InputDecoration(
            labelText: 'Infant\'s Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: _infantGender,
          decoration: InputDecoration(
            labelText: 'Infant\'s Gender',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
          items: ['Male', 'Female']
              .map((gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _infantGender = value;
            });
          },
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _infantAgeController,
          decoration: InputDecoration(
            labelText: 'Current Age of Infant',
            hintText: 'e.g., 2 weeks, 6 weeks',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Health Questions
        const Text(
          'Health Assessment',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          title: const Text(
              'Are you concerned about healing of your incision or tear?'),
          value: _incisionConcern,
          onChanged: (value) {
            setState(() {
              _incisionConcern = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text(
              'Are you experiencing heavy bleeding (soaking more than one pad per hour) or foul-smelling discharge?'),
          value: _heavyBleeding,
          onChanged: (value) {
            setState(() {
              _heavyBleeding = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text(
              'In the last 7 days, have you felt down, depressed, or hopeless?'),
          value: _depressed,
          onChanged: (value) {
            setState(() {
              _depressed = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text(
              'In the last 7 days, have you had little interest or pleasure in doing things?'),
          value: _noPleasure,
          onChanged: (value) {
            setState(() {
              _noPleasure = value!;
            });
          },
        ),
        const SizedBox(height: 15),

        // Feeding Information
        const Text(
          'Infant Feeding',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _feedingMethod,
          decoration: InputDecoration(
            labelText: 'Infant Feeding Method',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A90E2)),
            ),
          ),
          items: _feedingMethods
              .map((method) => DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _feedingMethod = value;
            });
          },
        ),
        const SizedBox(height: 15),
        CheckboxListTile(
          title: const Text(
              'Are you concerned about your baby\'s feeding or weight gain?'),
          value: _feedingConcern,
          onChanged: (value) {
            setState(() {
              _feedingConcern = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Has your baby had a fever in the last 24 hours?'),
          value: _infantFever,
          onChanged: (value) {
            setState(() {
              _infantFever = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text(
              'Is your baby having fewer than 6 wet diapers per day?'),
          value: _fewDiapers,
          onChanged: (value) {
            setState(() {
              _fewDiapers = value!;
            });
          },
        ),
        const SizedBox(height: 15),

        // Current Weight and Blood Pressure
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Weight',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Bold',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      hintText: 'kg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Blood Pressure',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Bold',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bloodPressureController,
                    decoration: InputDecoration(
                      hintText: 'mmHg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selection
        const Text(
          'Date of Appointment',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            DateTime today = DateTime.now();
            DateTime initial =
                _selectedDate ?? today.add(const Duration(days: 1));

            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: today,
              lastDate: today.add(const Duration(days: 365)),
            );
            if (picked != null) {
              if (!_isAllowedDate(picked)) {
                if (mounted) {
                  final String message = _isPrenatalUltrasound()
                      ? 'For ULTRASOUND (PRENATAL), appointments are only available on Wednesday (4:30 PM - 6:00 PM) and Saturday (10:00 AM - 12:00 PM).'
                      : 'Appointments are only available on Tuesday, Wednesday, Friday (4:00 PM - 6:00 PM) and Saturday (2:00 PM - 6:00 PM).';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              setState(() {
                _selectedDate = picked;
                _selectedTimeSlot = null;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                const SizedBox(width: 10),
                Text(
                  _selectedDate != null
                      ? _formatDate(_selectedDate!)
                      : 'Select Date',
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.black87 : Colors.grey,
                    fontFamily: 'Regular',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Time Slots
        const Text(
          'Available Time Slots',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.patientType == 'PRENATAL' &&
                  _selectedAppointmentType == 'Ultrasound'
              ? 'For ULTRASOUND (PRENATAL): Available days: Wednesday (4:30 PM - 6:00 PM) and Saturday (10:00 AM - 12:00 PM).'
              : 'Available days: Tuesday, Wednesday, Friday (4:00 PM - 6:00 PM) and Saturday (2:00 PM - 6:00 PM).',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Regular',
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<bool>>(
          future: _getTimeSlotAvailability(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            List<bool> availability =
                snapshot.data ?? List.filled(_timeSlots.length, true);

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_timeSlots.length, (index) {
                String timeSlot = _timeSlots[index];
                bool isSelected = _selectedTimeSlot == timeSlot;
                bool isAvailable = availability[index];

                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            _selectedTimeSlot = timeSlot;
                          });
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF4A90E2)
                          : isAvailable
                              ? Colors.grey.shade100
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Color(0xFF4A90E2)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAvailable ? Icons.access_time : Icons.block,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timeSlot,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isAvailable
                                    ? Colors.black87
                                    : Colors.grey.shade500,
                            fontFamily: isSelected ? 'Bold' : 'Regular',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  bool _isPrenatalUltrasound() {
    return widget.patientType == 'PRENATAL' &&
        _selectedAppointmentType == 'Ultrasound';
  }

  bool _isAllowedDate(DateTime date) {
    final int weekday = date.weekday;
    if (_isPrenatalUltrasound()) {
      // Ultrasound (PRENATAL): only Wednesday and Saturday
      return weekday == DateTime.wednesday || weekday == DateTime.saturday;
    }

    // Default: Tue, Wed, Fri, Sat
    return weekday == DateTime.tuesday ||
        weekday == DateTime.wednesday ||
        weekday == DateTime.friday ||
        weekday == DateTime.saturday;
  }

  List<String> _allowedSlotsForDate(DateTime date) {
    final int weekday = date.weekday;
    if (_isPrenatalUltrasound()) {
      if (weekday == DateTime.wednesday) {
        // Prenatal ultrasound: Wednesday 4:30 PM - 6:00 PM
        return ['4:30 PM', '5:00 PM', '5:30 PM', '6:00 PM'];
      }
      if (weekday == DateTime.saturday) {
        // Prenatal ultrasound: Saturday 10:00 AM - 12:00 PM
        return ['10:00 AM', '11:00 AM', '12:00 PM'];
      }
      return const [];
    }

    if (weekday == DateTime.saturday) {
      // Saturday: 2:00 PM - 6:00 PM
      return ['2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM', '6:00 PM'];
    }
    if (weekday == DateTime.tuesday ||
        weekday == DateTime.wednesday ||
        weekday == DateTime.friday) {
      // Tue/Wed/Fri: 4:00 PM - 6:00 PM
      return ['4:00 PM', '5:00 PM', '6:00 PM'];
    }
    return const [];
  }

  Future<List<bool>> _getTimeSlotAvailability() async {
    if (_selectedDate == null) return List.filled(_timeSlots.length, false);

    final allowedForDate = _allowedSlotsForDate(_selectedDate!);
    List<bool> availability = [];
    for (String timeSlot in _timeSlots) {
      if (!allowedForDate.contains(timeSlot)) {
        availability.add(false);
        continue;
      }
      int count =
          await _getAppointmentCountForTimeSlot(_selectedDate!, timeSlot);
      availability.add(count < 3);
    }
    return availability;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
