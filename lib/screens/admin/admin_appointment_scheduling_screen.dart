import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maternity_clinic/utils/colors.dart';
import 'package:maternity_clinic/services/notification_service.dart';
import 'package:maternity_clinic/services/audit_log_service.dart';

import 'admin_patient_records_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_appointment_management_screen.dart';
import '../auth/home_screen.dart';

class AdminAppointmentSchedulingScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const AdminAppointmentSchedulingScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<AdminAppointmentSchedulingScreen> createState() =>
      _AdminAppointmentSchedulingScreenState();
}

class _AdminAppointmentSchedulingScreenState
    extends State<AdminAppointmentSchedulingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  int _scheduledCount = 0;
  int _pendingCount = 0;
  int _cancelledCount = 0;
  final ScrollController _horizontalScrollController = ScrollController();
  String _selectedMaternityFilter = 'PRENATAL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      // Fetch all appointments
      final appointmentSnapshot =
          await _firestore.collection('appointments').get();

      // Fetch all users to get patient information
      final userSnapshot = await _firestore.collection('users').get();

      List<Map<String, dynamic>> appointments = [];
      Map<String, dynamic> users = {};

      // Create a map of users for easy lookup
      for (var doc in userSnapshot.docs) {
        users[doc.id] = doc.data();
      }

      // Process appointments
      int scheduled = 0;
      int pending = 0;
      int cancelled = 0;

      for (var doc in appointmentSnapshot.docs) {
        Map<String, dynamic> appointmentData = doc.data();
        String userId = appointmentData['userId'] ?? '';
        Map<String, dynamic>? userData = users[userId];

        // Create appointment with user information
        Map<String, dynamic> appointment = {
          'id': doc.id,
          'status': appointmentData['status'] ?? 'Pending',
          'appointment': _formatAppointment(appointmentData),
          'reason': appointmentData['reason'] ?? '',
          'notes': appointmentData['notes'] ?? '',
          'appointmentType': appointmentData['appointmentType'] ?? 'Clinic',
          'userId': userId,
          'appointmentDate': appointmentData['appointmentDate'],
          'createdAt': appointmentData['createdAt'],
          'timeSlot': appointmentData['timeSlot'],
          'day': appointmentData['day'],
        };

        // Add user information if available
        if (userData != null) {
          appointment['patientId'] = userData['userId'] ?? 'N/A';
          appointment['name'] = userData['name'] ?? 'Unknown';
          appointment['maternityStatus'] = userData['patientType'] ?? 'Unknown';
          appointment['email'] = userData['email'] ?? '';
          appointment['contactNumber'] = userData['contactNumber'] ?? '';
        } else {
          appointment['patientId'] = 'N/A';
          appointment['name'] = 'Unknown';
          appointment['maternityStatus'] = 'Unknown';
        }

        // Count by status
        String status = appointment['status'].toString().toLowerCase();
        if (status == 'accepted' || status == 'completed') {
          scheduled++;
        } else if (status == 'pending') {
          pending++;
        } else if (status == 'cancelled') {
          cancelled++;
        }

        // Do not include cancelled appointments in the schedules list
        if (status == 'cancelled') {
          continue;
        }
        if (status == 'pending') {
          continue;
        }
        if (status == 'completed') {
          continue;
        }

        appointments.add(appointment);
      }

      if (mounted) {
        setState(() {
          _appointments = appointments;
          _users = users.values.map((e) => e as Map<String, dynamic>).toList();
          _scheduledCount = scheduled;
          _pendingCount = pending;
          _cancelledCount = cancelled;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching appointments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatAppointment(Map<String, dynamic> appointmentData) {
    // Handle new appointment structure with appointmentDate
    if (appointmentData.containsKey('appointmentDate')) {
      Timestamp dateTimestamp = appointmentData['appointmentDate'];
      DateTime date = dateTimestamp.toDate();
      String timeSlot = appointmentData['timeSlot'] ?? 'Unknown';
      return '${_formatDate(date)}, $timeSlot';
    }

    // Handle old structure for backward compatibility
    String day = appointmentData['day'] ?? 'Unknown';
    String timeSlot = appointmentData['timeSlot'] ?? 'Unknown';
    return '$day, $timeSlot';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _acceptAppointment(String appointmentId, String patientName,
      Map<String, dynamic> appointmentData) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'Accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': widget.userName,
      });

      // Launch email client for notification
      final String email = (appointmentData['email'] ?? '').toString();
      final String phone = (appointmentData['contactNumber'] ?? '').toString();
      String dateText = '';
      final dynamic dateField = appointmentData['appointmentDate'];
      if (dateField is Timestamp) {
        final d = dateField.toDate();
        dateText = _formatDate(d);
      }
      final String timeSlot =
          (appointmentData['timeSlot'] ?? 'Unknown').toString();

      try {
        final notification = NotificationService();
        await notification.sendToUser(
          subject: 'Your appointment has been accepted',
          message:
              'Dear $patientName, your appointment on $dateText at $timeSlot has been accepted.\n\nThank you,\nVictory Lying-in Center',
          email: email,
          phone: phone,
          name: patientName,
        );
        await notification.sendToClinic(
          subject: 'Appointment accepted',
          message:
              '${widget.userName} accepted $patientName\'s appointment on $dateText at $timeSlot.',
        );
      } catch (_) {}

      await AuditLogService.log(
        role: widget.userRole,
        userName: widget.userName,
        action:
            '${widget.userName} accepted $patientName\'s appointment on $dateText at $timeSlot',
        entityType: 'appointments',
        entityId: appointmentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment for $patientName has been accepted',
              style: const TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAppointments(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
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
  }

  Future<void> _openPrenatalConsultation(
    String appointmentId,
    String patientName,
    Map<String, dynamic> appointmentData,
  ) async {
    Map<String, dynamic>? fullAppointment;
    Map<String, dynamic>? userData;
    String userId = (appointmentData['userId'] ?? '').toString();

    try {
      if (userId.isEmpty) {
        final doc = await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        if (doc.exists) {
          fullAppointment = doc.data() as Map<String, dynamic>;
          userId = (fullAppointment['userId'] ?? '').toString();
        }
      } else {
        final doc = await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        if (doc.exists) {
          fullAppointment = doc.data() as Map<String, dynamic>;
        }
      }

      if (userId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          userData = userDoc.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load consultation data: $e',
              style: const TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    DateTime? appointmentDate =
        _getAppointmentDateFromData(fullAppointment ?? appointmentData);
    DateTime? lmpDate;
    if (userData != null && userData!['lmpDate'] is Timestamp) {
      lmpDate = (userData!['lmpDate'] as Timestamp).toDate();
    }

    double? previousWeightKg;
    DateTime? previousDate;

    try {
      if (userId.isNotEmpty) {
        final snapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: userId)
            .get();

        List<Map<String, dynamic>> previousAppointments = [];
        for (var doc in snapshot.docs) {
          if (doc.id == appointmentId) continue;
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          previousAppointments.add(data);
        }

        previousAppointments = previousAppointments
            .where((a) => (a['status'] ?? '').toString() == 'Completed')
            .toList();

        previousAppointments.sort((a, b) {
          DateTime aDate = _getAppointmentDateFromData(a) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bDate = _getAppointmentDateFromData(b) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

        if (previousAppointments.isNotEmpty) {
          final latestPrev = previousAppointments.first;
          if (latestPrev['checkupWeightKg'] != null) {
            previousWeightKg =
                (latestPrev['checkupWeightKg'] as num).toDouble();
          } else if (latestPrev['weight'] != null) {
            previousWeightKg = double.tryParse(latestPrev['weight'].toString());
          }
          previousDate = _getAppointmentDateFromData(latestPrev);
        }
      }
    } catch (_) {}

    final TextEditingController weightController = TextEditingController();
    final TextEditingController systolicController = TextEditingController();
    final TextEditingController diastolicController = TextEditingController();
    final TextEditingController fhrController = TextEditingController();
    final TextEditingController fundalHeightController =
        TextEditingController();
    final TextEditingController remarksController = TextEditingController();
    final TextEditingController labRemarksController = TextEditingController();
    final TextEditingController findingsController = TextEditingController();
    final TextEditingController adviceController = TextEditingController();

    DateTime? nextVisitDate;
    String visitRiskStatus = 'LOW RISK';
    String riskExplanation = '';
    double? weightGainPerWeek;

    void evaluateRisk() {
      bool highRisk = false;
      List<String> reasons = [];

      final weightText = weightController.text.trim();
      if (weightText.isNotEmpty &&
          previousWeightKg != null &&
          previousDate != null &&
          appointmentDate != null) {
        final currentWeight = double.tryParse(weightText);
        if (currentWeight != null) {
          final daysBetween =
              appointmentDate!.difference(previousDate!).inDays.abs();
          if (daysBetween > 0) {
            final weeks = daysBetween / 7.0;
            if (weeks > 0) {
              weightGainPerWeek = (currentWeight - previousWeightKg!) / weeks;
              if (weightGainPerWeek != null && weightGainPerWeek! > 2.0) {
                highRisk = true;
                reasons.add('Weight gain > 2 kg/week');
              }
            }
          }
        }
      }

      final systolic = int.tryParse(systolicController.text.trim());
      final diastolic = int.tryParse(diastolicController.text.trim());
      if (systolic != null && diastolic != null) {
        if (systolic >= 140 || diastolic >= 90) {
          highRisk = true;
          reasons.add('BP 9140/90 (possible preeclampsia)');
        }
      }

      final fhr = int.tryParse(fhrController.text.trim());
      if (fhr != null && (fhr < 110 || fhr > 160)) {
        highRisk = true;
        reasons.add('Abnormal fetal heart rate');
      }

      final fundalText = fundalHeightController.text.trim();
      if (fundalText.isNotEmpty && lmpDate != null && appointmentDate != null) {
        final fh = double.tryParse(fundalText);
        if (fh != null) {
          final days = appointmentDate!.difference(lmpDate!).inDays;
          if (days >= 0) {
            final gaWeeks = days / 7.0;
            if ((fh - gaWeeks).abs() > 2.0) {
              highRisk = true;
              reasons.add('Fundal height 92 cm from GA');
            }
          }
        }
      }

      final remarksText = remarksController.text.toLowerCase();
      final List<String> keywords = [
        'edema',
        'swelling',
        'severe headache',
        'headache',
        'vision',
        'blurred vision',
        'vaginal bleeding',
        'bleeding',
      ];
      if (remarksText.isNotEmpty) {
        for (final k in keywords) {
          if (remarksText.contains(k)) {
            highRisk = true;
            reasons.add('Severe symptom: $k');
            break;
          }
        }
      }

      if (highRisk) {
        visitRiskStatus = 'HIGH RISK';
        riskExplanation = reasons.join('; ');
      } else {
        visitRiskStatus = 'LOW RISK';
        riskExplanation = '';
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        evaluateRisk();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Color riskColor = visitRiskStatus == 'HIGH RISK'
                ? Colors.red
                : visitRiskStatus == 'LOW RISK'
                    ? Colors.green
                    : Colors.orange;

            return AlertDialog(
              title: const Text(
                'Prenatal Consultation / Checkup',
                style: TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointmentData['appointment']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Step 2: Current Vitals (Checkup Details)',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      if (previousWeightKg != null && previousDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Previous weight: ${previousWeightKg!.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: systolicController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Systolic (mmHg)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setStateDialog(() {
                                  evaluateRisk();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: diastolicController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Diastolic (mmHg)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setStateDialog(() {
                                  evaluateRisk();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fhrController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fetal Heart Rate (bpm)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fundalHeightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fundal Height (cm)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      if (lmpDate != null && appointmentDate != null) ...[
                        const SizedBox(height: 4),
                        Builder(
                          builder: (_) {
                            final days =
                                appointmentDate!.difference(lmpDate!).inDays;
                            final gaWeeks = days >= 0 ? (days / 7.0) : 0.0;
                            return Text(
                              'Gestational age: ${gaWeeks.toStringAsFixed(1)} weeks',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Regular',
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: remarksController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Observations',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: labRemarksController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Remarks Laboratory Result',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: riskColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 14,
                                  color: riskColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Risk: $visitRiskStatus',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Bold',
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (riskExplanation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          riskExplanation,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Step 3: Doctor\'s Diagnosis & Advice',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: findingsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Findings',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: adviceController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Personalized Recommendation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: nextVisitDate ??
                                now.add(const Duration(days: 7)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              nextVisitDate = picked;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
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
                                nextVisitDate == null
                                    ? 'Select Next Visit Recommendation (optional)'
                                    : '${nextVisitDate!.month.toString().padLeft(2, '0')}/${nextVisitDate!.day.toString().padLeft(2, '0')}/${nextVisitDate!.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Regular',
                                  color: nextVisitDate == null
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
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
                  onPressed: () async {
                    final weightText = weightController.text.trim();
                    final systolicText = systolicController.text.trim();
                    final diastolicText = diastolicController.text.trim();
                    final fhrText = fhrController.text.trim();

                    if (weightText.isEmpty ||
                        systolicText.isEmpty ||
                        diastolicText.isEmpty ||
                        fhrText.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Please fill in all required vitals',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (findingsController.text.trim().isEmpty ||
                        adviceController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Please add findings and recommendations',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    evaluateRisk();

                    try {
                      double? weightKg = double.tryParse(weightText);
                      int? systolic = int.tryParse(systolicText);
                      int? diastolic = int.tryParse(diastolicText);
                      int? fhr = int.tryParse(fhrText);
                      double? fundalHeight =
                          double.tryParse(fundalHeightController.text.trim());

                      Map<String, dynamic> update = {
                        'status': 'Completed',
                        'completedAt': FieldValue.serverTimestamp(),
                        'completedBy': widget.userName,
                        'checkupWeightKg': weightKg,
                        'checkupBP_Systolic': systolic,
                        'checkupBP_Diastolic': diastolic,
                        'checkupBloodPressure':
                            '${systolic ?? ''}/${diastolic ?? ''}',
                        'checkupFetalHeartRateBpm': fhr,
                        'checkupFundalHeightCm': fundalHeight,
                        'checkupRemarks': remarksController.text.trim(),
                        'labRemarks': labRemarksController.text.trim(),
                        'visitRiskStatus': visitRiskStatus,
                        'findings': findingsController.text.trim(),
                        'advice': adviceController.text.trim(),
                        'notes': adviceController.text.trim(),
                      };

                      if (weightGainPerWeek != null) {
                        update['checkupWeightGainPerWeekKg'] =
                            weightGainPerWeek;
                        if (previousWeightKg != null) {
                          update['checkupPreviousWeightKg'] = previousWeightKg;
                        }
                      }

                      if (nextVisitDate != null) {
                        update['nextVisitDate'] =
                            Timestamp.fromDate(nextVisitDate!);
                      }

                      await _firestore
                          .collection('appointments')
                          .doc(appointmentId)
                          .update(update);

                      if (userId.isNotEmpty && visitRiskStatus == 'HIGH RISK') {
                        final userRef =
                            _firestore.collection('users').doc(userId);
                        final userSnap = await userRef.get();
                        if (userSnap.exists) {
                          final existing =
                              userSnap.data() as Map<String, dynamic>;
                          final existingRisk =
                              (existing['riskStatus'] ?? '').toString();
                          if (existingRisk != 'HIGH RISK') {
                            await userRef.update({'riskStatus': 'HIGH RISK'});
                          }
                        }
                      }

                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Consultation saved for $patientName',
                              style: const TextStyle(fontFamily: 'Regular'),
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _fetchAppointments();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to save consultation: $e',
                            style: const TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  child: const Text(
                    'Save & Finish',
                    style: TextStyle(
                      color: Colors.white,
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

    weightController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    fhrController.dispose();
    fundalHeightController.dispose();
    remarksController.dispose();
    labRemarksController.dispose();
    findingsController.dispose();
    adviceController.dispose();
  }

  Future<void> _openPostnatalConsultation(
    String appointmentId,
    String patientName,
    Map<String, dynamic> appointmentData,
  ) async {
    Map<String, dynamic>? fullAppointment;
    Map<String, dynamic>? userData;
    String userId = (appointmentData['userId'] ?? '').toString();

    try {
      if (userId.isEmpty) {
        final doc = await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        if (doc.exists) {
          fullAppointment = doc.data() as Map<String, dynamic>;
          userId = (fullAppointment['userId'] ?? '').toString();
        }
      } else {
        final doc = await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();
        if (doc.exists) {
          fullAppointment = doc.data() as Map<String, dynamic>;
        }
      }

      if (userId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          userData = userDoc.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load consultation data: $e',
              style: const TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    DateTime? appointmentDate =
        _getAppointmentDateFromData(fullAppointment ?? appointmentData);

    double? previousWeightKg;

    try {
      if (userId.isNotEmpty) {
        final snapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: userId)
            .get();

        List<Map<String, dynamic>> previousAppointments = [];
        for (var doc in snapshot.docs) {
          if (doc.id == appointmentId) continue;
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          previousAppointments.add(data);
        }

        previousAppointments = previousAppointments
            .where((a) => (a['status'] ?? '').toString() == 'Completed')
            .toList();

        previousAppointments.sort((a, b) {
          DateTime aDate = _getAppointmentDateFromData(a) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bDate = _getAppointmentDateFromData(b) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

        if (previousAppointments.isNotEmpty) {
          final latestPrev = previousAppointments.first;
          if (latestPrev['postnatalWeightKg'] != null) {
            previousWeightKg =
                (latestPrev['postnatalWeightKg'] as num).toDouble();
          } else if (latestPrev['checkupWeightKg'] != null) {
            previousWeightKg =
                (latestPrev['checkupWeightKg'] as num).toDouble();
          } else if (latestPrev['weight'] != null) {
            previousWeightKg = double.tryParse(latestPrev['weight'].toString());
          }
        }
      }
    } catch (_) {}

    final TextEditingController weightController = TextEditingController();
    final TextEditingController systolicController = TextEditingController();
    final TextEditingController diastolicController = TextEditingController();
    final TextEditingController uterineInvolutionController =
        TextEditingController();
    final TextEditingController remarksController = TextEditingController();
    final TextEditingController findingsController = TextEditingController();
    final TextEditingController adviceController = TextEditingController();

    DateTime? nextVisitDate;
    String visitRiskStatus = 'LOW RISK';
    String riskExplanation = '';

    String? lochiaType = 'Rubra';
    String? lochiaAmount = 'Light';
    String? lochiaSmell = 'Normal';
    String? woundStatus = 'Clean';

    void evaluateRisk() {
      bool highRisk = false;
      List<String> reasons = [];

      final weightText = weightController.text.trim();
      if (weightText.isNotEmpty && previousWeightKg != null) {
        final currentWeight = double.tryParse(weightText);
        if (currentWeight != null) {
          final diff = currentWeight - previousWeightKg!;
          if (diff <= -3.0) {
            highRisk = true;
            reasons.add('Sudden postpartum weight loss');
          } else if (diff >= 0.0) {
            highRisk = true;
            reasons.add('No postpartum weight reduction');
          }
        }
      }

      final systolic = int.tryParse(systolicController.text.trim());
      final diastolic = int.tryParse(diastolicController.text.trim());
      if (systolic != null && diastolic != null) {
        if (systolic >= 140 || diastolic >= 90) {
          highRisk = true;
          reasons.add(
              'BP 9140/90 (possible postpartum hypertension / preeclampsia)');
        }
      }

      final uiText = uterineInvolutionController.text.toLowerCase();
      if (uiText.contains('soft') ||
          uiText.contains('boggy') ||
          uiText.contains('not firm')) {
        highRisk = true;
        reasons.add('Uterus soft / not well contracted');
      }

      if (lochiaAmount == 'Heavy') {
        highRisk = true;
        reasons.add('Heavy lochia');
      }
      if (lochiaSmell == 'Foul') {
        highRisk = true;
        reasons.add('Foul-smelling lochia');
      }

      if (woundStatus != null) {
        final w = woundStatus!.toLowerCase();
        if (w.contains('red') ||
            w.contains('discharge') ||
            w.contains('pus') ||
            w.contains('infect')) {
          highRisk = true;
          reasons.add('Wound with redness/discharge (possible infection)');
        }
      }

      final remarksText = remarksController.text.toLowerCase();
      final severeKeywords = [
        'fever',
        'chills',
        'heavy bleeding',
        'hemorrhage',
        'infection',
        'foul smell',
      ];
      if (remarksText.isNotEmpty) {
        for (final k in severeKeywords) {
          if (remarksText.contains(k)) {
            highRisk = true;
            reasons.add('Severe symptom: $k');
            break;
          }
        }
      }

      if (highRisk) {
        visitRiskStatus = 'HIGH RISK';
        riskExplanation = reasons.join('; ');
      } else {
        visitRiskStatus = 'LOW RISK';
        riskExplanation = '';
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        evaluateRisk();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Color riskColor = visitRiskStatus == 'HIGH RISK'
                ? Colors.red
                : visitRiskStatus == 'LOW RISK'
                    ? Colors.green
                    : Colors.orange;

            return AlertDialog(
              title: const Text(
                'Postnatal Consultation / Checkup',
                style: TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointmentData['appointment']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Step 2: Current Vitals (Postnatal Mother Only)',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      if (previousWeightKg != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Previous weight: ${previousWeightKg!.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: systolicController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Systolic (mmHg)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setStateDialog(() {
                                  evaluateRisk();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: diastolicController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Diastolic (mmHg)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setStateDialog(() {
                                  evaluateRisk();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: uterineInvolutionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText:
                              'Uterine Involution (fundus level / firm or soft)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Lochia Assessment',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: lochiaType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Rubra', child: Text('Rubra')),
                                DropdownMenuItem(
                                    value: 'Serosa', child: Text('Serosa')),
                                DropdownMenuItem(
                                    value: 'Alba', child: Text('Alba')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  lochiaType = value;
                                  evaluateRisk();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: lochiaAmount,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Light', child: Text('Light')),
                                DropdownMenuItem(
                                    value: 'Moderate', child: Text('Moderate')),
                                DropdownMenuItem(
                                    value: 'Heavy', child: Text('Heavy')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  lochiaAmount = value;
                                  evaluateRisk();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: lochiaSmell,
                        decoration: const InputDecoration(
                          labelText: 'Smell',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'Foul', child: Text('Foul')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            lochiaSmell = value;
                            evaluateRisk();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: woundStatus,
                        decoration: const InputDecoration(
                          labelText: 'Incision / Wound Check',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Clean', child: Text('Clean')),
                          DropdownMenuItem(
                              value: 'Redness', child: Text('Redness')),
                          DropdownMenuItem(
                              value: 'Discharge', child: Text('Discharge')),
                          DropdownMenuItem(
                            value: 'Redness with Discharge',
                            child: Text('Redness with Discharge'),
                          ),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            woundStatus = value;
                            evaluateRisk();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: remarksController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Observations',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setStateDialog(() {
                            evaluateRisk();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: riskColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 14,
                                  color: riskColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Risk: $visitRiskStatus',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Bold',
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (riskExplanation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          riskExplanation,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Step 3: Doctor\'s Diagnosis & Advice',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Bold',
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: findingsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Findings',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: adviceController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Personalized Recommendation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: nextVisitDate ??
                                now.add(const Duration(days: 7)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              nextVisitDate = picked;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
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
                                nextVisitDate == null
                                    ? 'Select Next Visit Recommendation (optional)'
                                    : '${nextVisitDate!.month.toString().padLeft(2, '0')}/${nextVisitDate!.day.toString().padLeft(2, '0')}/${nextVisitDate!.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Regular',
                                  color: nextVisitDate == null
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
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
                  onPressed: () async {
                    final weightText = weightController.text.trim();
                    final systolicText = systolicController.text.trim();
                    final diastolicText = diastolicController.text.trim();

                    if (weightText.isEmpty ||
                        systolicText.isEmpty ||
                        diastolicText.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Please fill in all required vitals',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (findingsController.text.trim().isEmpty ||
                        adviceController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Please add findings and recommendations',
                            style: TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    evaluateRisk();

                    try {
                      double? weightKg = double.tryParse(weightText);
                      int? systolic = int.tryParse(systolicText);
                      int? diastolic = int.tryParse(diastolicText);

                      Map<String, dynamic> update = {
                        'status': 'Completed',
                        'completedAt': FieldValue.serverTimestamp(),
                        'completedBy': widget.userName,
                        'postnatalWeightKg': weightKg,
                        'postnatalBP_Systolic': systolic,
                        'postnatalBP_Diastolic': diastolic,
                        'postnatalBloodPressure':
                            '${systolic ?? ''}/${diastolic ?? ''}',
                        'postnatalUterineInvolution':
                            uterineInvolutionController.text.trim(),
                        'postnatalLochiaType': lochiaType,
                        'postnatalLochiaAmount': lochiaAmount,
                        'postnatalLochiaSmell': lochiaSmell,
                        'postnatalWoundStatus': woundStatus,
                        'postnatalRemarks': remarksController.text.trim(),
                        'visitRiskStatus': visitRiskStatus,
                        'findings': findingsController.text.trim(),
                        'advice': adviceController.text.trim(),
                        'notes': adviceController.text.trim(),
                      };

                      if (nextVisitDate != null) {
                        update['nextVisitDate'] =
                            Timestamp.fromDate(nextVisitDate!);
                      }

                      await _firestore
                          .collection('appointments')
                          .doc(appointmentId)
                          .update(update);

                      if (userId.isNotEmpty && visitRiskStatus == 'HIGH RISK') {
                        final userRef =
                            _firestore.collection('users').doc(userId);
                        final userSnap = await userRef.get();
                        if (userSnap.exists) {
                          final existing =
                              userSnap.data() as Map<String, dynamic>;
                          final existingRisk =
                              (existing['riskStatus'] ?? '').toString();
                          if (existingRisk != 'HIGH RISK') {
                            await userRef.update({'riskStatus': 'HIGH RISK'});
                          }
                        }
                      }

                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Consultation saved for $patientName',
                              style: const TextStyle(fontFamily: 'Regular'),
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _fetchAppointments();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to save consultation: $e',
                            style: const TextStyle(fontFamily: 'Regular'),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  child: const Text(
                    'Save & Finish',
                    style: TextStyle(
                      color: Colors.white,
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

    weightController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    uterineInvolutionController.dispose();
    remarksController.dispose();
    findingsController.dispose();
    adviceController.dispose();
  }

  Future<void> _cancelAppointment(String appointmentId, String patientName,
      Map<String, dynamic> appointmentData) async {
    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cancel Appointment',
            style: const TextStyle(fontFamily: 'Bold'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient: $patientName',
                style: const TextStyle(
                  fontFamily: 'Regular',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Are you sure you want to cancel this appointment?',
                style: TextStyle(fontFamily: 'Regular'),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'This will:\n• Mark appointment as cancelled\n• Add cancellation timestamp\n• Update patient records',
                  style: TextStyle(
                    fontFamily: 'Regular',
                    fontSize: 12,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: Colors.grey.shade600, fontFamily: 'Regular'),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Bold',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('appointments').doc(appointmentId).update({
          'status': 'Cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': widget.userName,
        });

        // Launch email client for notification
        final String email = (appointmentData['email'] ?? '').toString();
        final String phone =
            (appointmentData['contactNumber'] ?? '').toString();
        String dateText = '';
        final dynamic dateField = appointmentData['appointmentDate'];
        if (dateField is Timestamp) {
          final d = dateField.toDate();
          dateText = _formatDate(d);
        }
        final String timeSlot =
            (appointmentData['timeSlot'] ?? 'Unknown').toString();

        try {
          final notification = NotificationService();
          await notification.sendToUser(
            subject: 'Your appointment has been cancelled',
            message:
                'Dear $patientName, your appointment on $dateText at $timeSlot has been cancelled.\n\nIf you have any questions, please contact the clinic.',
            email: email,
            phone: phone,
            name: patientName,
          );
          await notification.sendToClinic(
            subject: 'Appointment cancelled',
            message:
                '${widget.userName} cancelled $patientName\'s appointment on $dateText at $timeSlot.',
          );
        } catch (_) {}

        await AuditLogService.log(
          role: widget.userRole,
          userName: widget.userName,
          action:
              '${widget.userName} cancelled $patientName\'s appointment on $dateText at $timeSlot',
          entityType: 'appointments',
          entityId: appointmentId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Appointment for $patientName has been cancelled',
                style: const TextStyle(fontFamily: 'Regular'),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchAppointments(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
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
    }
  }

  Future<void> _completeAppointment(
      String appointmentId, String patientName) async {
    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Complete Appointment',
            style: const TextStyle(fontFamily: 'Bold'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient: $patientName',
                style: const TextStyle(
                  fontFamily: 'Regular',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Are you sure you want to mark this appointment as completed?',
                style: TextStyle(fontFamily: 'Regular'),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Text(
                  'This will:\n• Mark appointment as completed\n• Add completion timestamp\n• Update patient records',
                  style: TextStyle(
                    fontFamily: 'Regular',
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: Colors.grey.shade600, fontFamily: 'Regular'),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Complete',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Bold',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('appointments').doc(appointmentId).update({
          'status': 'Completed',
          'completedAt': FieldValue.serverTimestamp(),
          'completedBy': widget.userName,
        });

        try {
          final doc = await _firestore
              .collection('appointments')
              .doc(appointmentId)
              .get();
          final data = doc.data();
          final String userId = (data?['userId'] ?? '').toString();
          String email = '';
          String phone = '';
          String dateText = '';
          final dynamic dateField = data?['appointmentDate'];
          if (dateField is Timestamp) {
            final d = dateField.toDate();
            dateText = _formatDate(d);
          }
          final String timeSlot = (data?['timeSlot'] ?? '').toString();

          if (userId.isNotEmpty) {
            final userDoc =
                await _firestore.collection('users').doc(userId).get();
            final userData = userDoc.data();
            email = (userData?['email'] ?? '').toString();
            phone = (userData?['contactNumber'] ?? '').toString();
          }

          final notification = NotificationService();
          await notification.sendToUser(
            subject: 'Your appointment has been completed',
            message:
                'Dear $patientName, your appointment on $dateText at $timeSlot has been completed.\n\nThank you,\nVictory Lying-in Center',
            email: email,
            phone: phone,
            name: patientName,
          );
          await notification.sendToClinic(
            subject: 'Appointment completed',
            message:
                '${widget.userName} marked $patientName\'s appointment on $dateText at $timeSlot as completed.',
          );

          await AuditLogService.log(
            role: widget.userRole,
            userName: widget.userName,
            action:
                '${widget.userName} marked $patientName\'s appointment on $dateText at $timeSlot as completed',
            entityType: 'appointments',
            entityId: appointmentId,
          );
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Appointment for $patientName has been marked as completed',
                style: const TextStyle(fontFamily: 'Regular'),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          _fetchAppointments(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to complete appointment: $e',
                style: const TextStyle(fontFamily: 'Regular'),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _rescheduleAppointment(String appointmentId, String patientName,
      Map<String, dynamic> currentAppointment) async {
    // Show dialog to select new date and time
    DateTime? selectedDate;
    String? selectedTime;
    List<String> availableTimeSlots = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Reschedule Appointment',
                style: const TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: $patientName',
                      style: const TextStyle(
                        fontFamily: 'Regular',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Current: ${currentAppointment['appointment']}',
                      style: const TextStyle(fontFamily: 'Regular'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select New Date:',
                      style: TextStyle(
                        fontFamily: 'Bold',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final DateTime today = DateTime.now();
                        final DateTime initial =
                            selectedDate ?? today.add(const Duration(days: 1));

                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: today,
                          lastDate: today.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          if (!_isAllowedRescheduleDate(picked)) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Appointments are only available on Tuesday, Wednesday, Friday (4:00 PM - 6:00 PM) and Saturday (2:00 PM - 6:00 PM).'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          setState(() {
                            selectedDate = picked;
                            selectedTime = null;
                            availableTimeSlots =
                                _allowedSlotsForReschedule(picked);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedDate != null
                              ? _formatDate(selectedDate!)
                              : 'Select Date',
                          style: TextStyle(
                            fontFamily: 'Regular',
                            color: selectedDate != null
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select New Time:',
                      style: TextStyle(
                        fontFamily: 'Bold',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedDate == null)
                      const Text(
                        'Please select a date first.',
                        style: TextStyle(
                          fontFamily: 'Regular',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableTimeSlots.map((time) {
                          bool isSelected = selectedTime == time;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedTime = time;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? primary : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontFamily: 'Regular',
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontFamily: 'Regular'),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedDate != null && selectedTime != null
                      ? () async {
                          Navigator.pop(context);
                          final String email =
                              (currentAppointment['email'] ?? '').toString();
                          final String phone =
                              (currentAppointment['contactNumber'] ?? '')
                                  .toString();
                          await _updateAppointment(
                            appointmentId,
                            patientName,
                            selectedDate!,
                            selectedTime!,
                            email: email,
                            phone: phone,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  child: const Text(
                    'Reschedule',
                    style: TextStyle(
                      color: Colors.white,
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

  Future<void> _updateAppointment(String appointmentId, String patientName,
      DateTime newDate, String newTime,
      {String? email, String? phone}) async {
    try {
      // Prevent overbooking: max 3 appointments per time slot per day
      final DateTime startOfDay =
          DateTime(newDate.year, newDate.month, newDate.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('appointments')
          .where('appointmentDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('timeSlot', isEqualTo: newTime)
          .get();

      int existingCount = 0;
      for (var doc in snapshot.docs) {
        if (doc.id == appointmentId) continue;
        existingCount++;
      }

      if (existingCount >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'This time slot is no longer available. Please select another time.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _firestore.collection('appointments').doc(appointmentId).update({
        'appointmentDate': Timestamp.fromDate(newDate),
        'timeSlot': newTime,
        'rescheduledAt': FieldValue.serverTimestamp(),
        'status': 'Rescheduled',
        'rescheduleReason': 'Admin rescheduled appointment',
      });

      // Launch email client for reschedule notification
      try {
        final notification = NotificationService();
        await notification.sendToUser(
          subject: 'Your appointment has been rescheduled',
          message:
              'Dear $patientName, your appointment has been rescheduled to ${_formatDate(newDate)}, $newTime.\n\nThank you,\nVictory Lying-in Center',
          email: (email ?? '').isNotEmpty ? email : null,
          phone: (phone ?? '').isNotEmpty ? phone : null,
          name: patientName,
        );
        await notification.sendToClinic(
          subject: 'Appointment rescheduled',
          message:
              '${widget.userName} rescheduled $patientName\'s appointment to ${_formatDate(newDate)} at $newTime.',
        );
      } catch (_) {}

      await AuditLogService.log(
        role: widget.userRole,
        userName: widget.userName,
        action:
            '${widget.userName} rescheduled $patientName\'s appointment to ${_formatDate(newDate)} at $newTime',
        entityType: 'appointments',
        entityId: appointmentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment for $patientName has been rescheduled to ${_formatDate(newDate)}, $newTime',
              style: const TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        _fetchAppointments(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to reschedule appointment: $e',
              style: const TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _isAllowedRescheduleDate(DateTime date) {
    final int weekday = date.weekday;
    return weekday == DateTime.tuesday ||
        weekday == DateTime.wednesday ||
        weekday == DateTime.friday ||
        weekday == DateTime.saturday;
  }

  List<String> _allowedSlotsForReschedule(DateTime date) {
    final int weekday = date.weekday;
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

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: const [
                      Icon(Icons.event_available,
                          size: 28, color: Colors.black87),
                      SizedBox(width: 12),
                      Text(
                        'Approve Schedules',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Filters: Prenatal/Postnatal + Search
                  Row(
                    children: [
                      ToggleButtons(
                        isSelected: [
                          _selectedMaternityFilter == 'PRENATAL',
                          _selectedMaternityFilter == 'POSTNATAL',
                        ],
                        onPressed: (index) {
                          setState(() {
                            _selectedMaternityFilter =
                                index == 0 ? 'PRENATAL' : 'POSTNATAL';
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        selectedColor: Colors.white,
                        color: Colors.black87,
                        fillColor: primary,
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 140,
                        ),
                        children: const [
                          Text(
                            'Prenatal Approved',
                            style:
                                TextStyle(fontFamily: 'Medium', fontSize: 12),
                          ),
                          Text(
                            'Postnatal Approved',
                            style:
                                TextStyle(fontFamily: 'Medium', fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search name...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Appointments Table
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: primary))
                          : _appointments.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No appointments found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Regular',
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: _horizontalScrollController,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildAppointmentsTable(),
                                    ),
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
          _buildMenuItem('DATA GRAPHS', false),
          _buildMenuItem('APPOINTMENT MANAGEMENT', false),
          _buildMenuItem('APPROVE SCHEDULES', true),
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
        // Already on this screen
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
      case 'LOGOUT':
        _showLogoutConfirmationDialog();
        break;
    }
  }

  Widget _buildStatCard(String number, String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 28, color: primary),
                const SizedBox(width: 8),
              ],
              Text(
                number,
                style: const TextStyle(
                  fontSize: 28,
                  fontFamily: 'Bold',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTable() {
    const double columnWidth = 120.0;

    // Filter appointments by maternity type and search query
    final List<Map<String, dynamic>> filtered = _appointments.where((a) {
      final String maternity =
          (a['maternityStatus'] ?? '').toString().toUpperCase();
      if (_selectedMaternityFilter == 'PRENATAL' && maternity != 'PRENATAL') {
        return false;
      }
      if (_selectedMaternityFilter == 'POSTNATAL' && maternity != 'POSTNATAL') {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: columnWidth * 0.8,
                  child: _buildHeaderCell('NO.'),
                ),
                SizedBox(
                  width: columnWidth * 1.4,
                  child: _buildHeaderCell('NAME'),
                ),
                SizedBox(
                  width: columnWidth * 1.1,
                  child: _buildHeaderCell('STATUS'),
                ),
                SizedBox(
                  width: columnWidth * 1.3,
                  child: _buildHeaderCell('APPOINTMENT DATE'),
                ),
                SizedBox(
                  width: columnWidth * 1.3,
                  child: _buildHeaderCell('APPOINTMENT TYPE'),
                ),
                SizedBox(
                  width: columnWidth * 2.3,
                  child: _buildHeaderCell('ACTIONS'),
                ),
              ],
            ),
          ),

          // Table Rows
          ...filtered.asMap().entries.map((entry) {
            final index = entry.key;
            final appointment = entry.value;
            return _buildTableRow(
              appointment['id'] ?? '',
              (index + 1).toString(),
              appointment['name'] ?? 'Unknown',
              appointment['status'] ?? 'Pending',
              appointment['maternityStatus'] ?? 'Unknown',
              appointment,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontFamily: 'Bold',
        color: Colors.black87,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTableRow(
    String appointmentId,
    String rowNumber,
    String name,
    String status,
    String maternityStatus,
    Map<String, dynamic> appointmentData,
  ) {
    Color statusColor;
    IconData statusIcon;

    if (status == 'Pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    } else if (status == 'Accepted') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'Rescheduled') {
      statusColor = Colors.blue;
      statusIcon = Icons.event;
    } else if (status == 'Completed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    // Format timestamps for display
    String statusTimestamp = '';
    if (appointmentData['acceptedAt'] != null && status == 'Accepted') {
      final timestamp = appointmentData['acceptedAt'] as Timestamp;
      final date = timestamp.toDate();
      statusTimestamp = 'Accepted: ${_formatDateTime(date)}';
    } else if (appointmentData['rescheduledAt'] != null &&
        status == 'Rescheduled') {
      final timestamp = appointmentData['rescheduledAt'] as Timestamp;
      final date = timestamp.toDate();
      statusTimestamp = 'Rescheduled: ${_formatDateTime(date)}';
    } else if (appointmentData['completedAt'] != null &&
        status == 'Completed') {
      final timestamp = appointmentData['completedAt'] as Timestamp;
      final date = timestamp.toDate();
      final completedBy = appointmentData['completedBy'] ?? 'System';
      statusTimestamp = 'Completed: ${_formatDateTime(date)} by $completedBy';
    } else if (appointmentData['cancelledAt'] != null &&
        status == 'Cancelled') {
      final timestamp = appointmentData['cancelledAt'] as Timestamp;
      final date = timestamp.toDate();
      statusTimestamp = 'Cancelled: ${_formatDateTime(date)}';
    }

    const double columnWidth = 120.0;

    // Appointment date and type for new layout
    String appointmentDateText = '-';
    final DateTime? apptDate = _getAppointmentDateFromData(appointmentData);
    if (apptDate != null) {
      appointmentDateText = _formatDate(apptDate);
    }
    String appointmentTypeText =
        (appointmentData['appointmentType'] ?? 'Clinic').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // NO. Column
          SizedBox(
            width: columnWidth * 0.8,
            child: _buildTableCell(rowNumber),
          ),
          // NAME Column
          SizedBox(
            width: columnWidth * 1.2,
            child: _buildTableCell(name),
          ),
          // STATUS Column
          SizedBox(
            width: columnWidth * 1.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Bold',
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (statusTimestamp.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusTimestamp,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'Regular',
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // APPOINTMENT DATE Column
          SizedBox(
            width: columnWidth * 1.3,
            child: _buildTableCell(appointmentDateText),
          ),
          // APPOINTMENT TYPE Column
          SizedBox(
            width: columnWidth * 1.3,
            child: _buildTableCell(appointmentTypeText),
          ),
          // ACTIONS Column
          SizedBox(
            width: columnWidth * 2.5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status == 'Pending')
                  TextButton(
                    onPressed: () => _acceptAppointment(
                        appointmentId, name, appointmentData),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Bold',
                        color: Colors.green,
                      ),
                    ),
                  ),
                if (status == 'Accepted' || status == 'Rescheduled')
                  TextButton(
                    onPressed: () => _rescheduleAppointment(
                        appointmentId, name, appointmentData),
                    child: const Text(
                      'Reschedule',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Bold',
                        color: Colors.orange,
                      ),
                    ),
                  ),
                if (status != 'Cancelled' && status != 'Completed')
                  TextButton(
                    onPressed: () => _cancelAppointment(
                        appointmentId, name, appointmentData),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Bold',
                        color: Colors.red,
                      ),
                    ),
                  ),
                if (status == 'Accepted' || status == 'Rescheduled') ...[
                  if (maternityStatus == 'PRENATAL')
                    TextButton(
                      onPressed: () => _openPrenatalConsultation(
                          appointmentId, name, appointmentData),
                      child: const Text(
                        'Start Consultation',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Bold',
                          color: Colors.blue,
                        ),
                      ),
                    )
                  else if (maternityStatus == 'POSTNATAL')
                    TextButton(
                      onPressed: () => _openPostnatalConsultation(
                          appointmentId, name, appointmentData),
                      child: const Text(
                        'Start Consultation',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Bold',
                          color: Colors.blue,
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () =>
                          _completeAppointment(appointmentId, name),
                      child: const Text(
                        'Complete',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Bold',
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _getAppointmentDateFromData(Map<String, dynamic> data) {
    if (data['appointmentDate'] is Timestamp) {
      return (data['appointmentDate'] as Timestamp).toDate();
    }
    if (data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).toDate();
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTableCell(String text) {
    return Text(
      text.isNotEmpty ? text : '-',
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'Regular',
        color: text.isNotEmpty ? Colors.grey.shade700 : Colors.grey.shade400,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }
}
