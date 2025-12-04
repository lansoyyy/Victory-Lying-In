import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/colors.dart';

class RequestCheckupDialog extends StatefulWidget {
  final String patientType; // 'PRENATAL' or 'POSTNATAL'

  const RequestCheckupDialog({
    super.key,
    required this.patientType,
  });

  @override
  State<RequestCheckupDialog> createState() => _RequestCheckupDialogState();
}

class _RequestCheckupDialogState extends State<RequestCheckupDialog> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _specificConcernController =
      TextEditingController();
  final TextEditingController _chiefComplaintController =
      TextEditingController();

  String? _selectedAppointmentType;
  DateTime? _preferredDate;
  bool _isSubmitting = false;

  final List<String> _prenatalAppointmentTypes = const [
    'First Checkup',
    'Routine Prenatal Checkup',
    'Follow-up (Reading of Lab Results)',
    'Specific Concern',
  ];

  final List<String> _postnatalAppointmentTypes = const [
    'First Postnatal Checkup',
    'Routine Postnatal Checkup',
    'Follow-up (Review of medication/wound check)',
    'Specific Concern',
  ];

  @override
  void dispose() {
    _specificConcernController.dispose();
    _chiefComplaintController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    if (_selectedAppointmentType == null) {
      _showError('Please select appointment type');
      return;
    }
    if (_preferredDate == null) {
      _showError('Please select preferred date');
      return;
    }
    if (_selectedAppointmentType == 'Specific Concern' &&
        _specificConcernController.text.trim().isEmpty) {
      _showError('Please describe your specific concern');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showError('You must be signed in to request a checkup');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _firestore.collection('checkupRequests').add({
        'userId': user.uid,
        'patientType': widget.patientType,
        'appointmentType': _selectedAppointmentType,
        'specificConcern': _selectedAppointmentType == 'Specific Concern'
            ? _specificConcernController.text.trim()
            : '',
        'preferredDate': Timestamp.fromDate(_preferredDate!),
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
        'remarks': '',
        'linkedAppointmentId': null,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Checkup request submitted successfully',
              style: TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to submit request. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Request Checkup',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Bold',
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.patientType == 'POSTNATAL'
                    ? 'Fill out this form to request a postnatal checkup. The clinic will review and schedule your appointment.'
                    : 'Fill out this form to request a prenatal checkup. The clinic will review and schedule your appointment.',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Regular',
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),

              // Appointment Type
              const Text(
                'Appointment Type',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAppointmentType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: (widget.patientType == 'POSTNATAL'
                        ? _postnatalAppointmentTypes
                        : _prenatalAppointmentTypes)
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
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedAppointmentType = value;
                        });
                      },
              ),
              const SizedBox(height: 12),

              if (_selectedAppointmentType == 'Specific Concern') ...[
                const Text(
                  'Specific Concern',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _specificConcernController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Describe your specific concern',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontFamily: 'Regular',
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 12),
              ],

              // Preferred Date
              const Text(
                'Preferred Date',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _preferredDate ?? now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _preferredDate = picked;
                          });
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _preferredDate == null
                            ? 'Select preferred date'
                            : '${_preferredDate!.month.toString().padLeft(2, '0')}/${_preferredDate!.day.toString().padLeft(2, '0')}/${_preferredDate!.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                          color: _preferredDate == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Chief Complaint (optional)
              const Text(
                'Chief Complaint (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _chiefComplaintController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Describe your main symptom or reason for consultation',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontFamily: 'Regular',
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
                enabled: !_isSubmitting,
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.pop(context, false);
                          },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontFamily: 'Regular',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Bold',
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
