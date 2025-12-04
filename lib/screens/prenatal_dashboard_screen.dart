import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';
import '../widgets/forgot_password_dialog.dart';
import 'prenatal_history_checkup_screen.dart';
import 'notification_appointment_screen.dart';
import 'transfer_record_request_screen.dart';
import 'prenatal_update_profile_screen.dart';
import 'auth/home_screen.dart';

class PrenatalDashboardScreen extends StatefulWidget {
  final bool openPersonalDetailsOnLoad;

  const PrenatalDashboardScreen({
    super.key,
    this.openPersonalDetailsOnLoad = false,
  });

  @override
  State<PrenatalDashboardScreen> createState() =>
      _PrenatalDashboardScreenState();
}

class _PrenatalDashboardScreenState extends State<PrenatalDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = 'Loading...';
  bool _profileCompleted = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.openPersonalDetailsOnLoad) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PrenatalUpdateProfileScreen(),
          ),
        );
      }
    });
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
              _profileCompleted = userData['profileCompleted'] == true;
              _userData = userData;
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_profileCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Required Profile Information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Bold',
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Before you can book an appointment you need to fill out "Update Profile".',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Regular',
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PrenatalUpdateProfileScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Go to Update Profile',
                                      style: TextStyle(
                                        color: primary,
                                        fontFamily: 'Bold',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    'Healthy Pregnancy, Healthy Baby: A Guide to\nPrenatal Care',
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: 'Bold',
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildGuideGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedEducationalSection() {
    final user = _auth.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personalized Health Tips',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Bold',
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Articles selected based on your trimester and clinical risk information.',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('educationalArticles')
              .where('category', isEqualTo: 'PRENATAL')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(color: primary),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No personalized tips yet.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade600,
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _articleMatchesPrenatalPatient(data);
            }).toList();

            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No personalized tips match your current profile.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade600,
                  ),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title']?.toString() ?? '';
                final body = data['body']?.toString() ?? '';
                final tags = (data['targetTags'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Bold',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Regular',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  bool _articleMatchesPrenatalPatient(Map<String, dynamic> article) {
    final rawTags = article['targetTags'];
    final List<String> tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    if (tags.isEmpty) {
      return true;
    }

    final patientTags = _getPrenatalPatientTags();
    if (patientTags.isEmpty) {
      return false;
    }

    for (final tag in tags) {
      if (patientTags.contains(tag)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _getPrenatalPatientTags() {
    final Set<String> tags = {};
    final data = _userData ?? {};

    // Trimester based on LMP
    if (data['lmpDate'] is Timestamp) {
      final DateTime lmp = (data['lmpDate'] as Timestamp).toDate();
      final int days = DateTime.now().difference(lmp).inDays;
      if (days >= 0) {
        final double weeks = days / 7.0;
        if (weeks < 14) {
          tags.add('1st Trimester');
        } else if (weeks < 28) {
          tags.add('2nd Trimester');
        } else {
          tags.add('3rd Trimester');
        }
      }
    }

    final riskStatus =
        (data['riskStatus'] ?? '').toString().toUpperCase().trim();
    final complication =
        (data['specificComplication'] ?? '').toString().toLowerCase();

    if (riskStatus == 'HIGH RISK') {
      if (complication.contains('gdm') ||
          complication.contains('gestational diabetes') ||
          complication.contains('diabetes')) {
        tags.add('High Risk-Diabetes');
      }

      if (complication.contains('preeclampsia') ||
          complication.contains('eclampsia') ||
          complication.contains('hypertension') ||
          complication.contains('high blood pressure')) {
        tags.add('High Risk-Hypertension');
      }
    }

    return tags;
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
                const Text(
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

          // Menu Items
          _buildMenuItem('PERSONAL DETAILS', false),
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
          // Handle menu navigation
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrenatalUpdateProfileScreen(),
              ),
            );
          } else if (title == 'HISTORY OF\nCHECK UP') {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PrenatalHistoryCheckupScreen()),
            );
          } else if (title == 'REQUEST &\nNOTIFICATION APPOINTMENT') {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NotificationAppointmentScreen(
                      patientType: 'PRENATAL')),
            );
          } else if (title == 'TRANSFER OF\nRECORD REQUEST') {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransferRecordRequestScreen(
                      patientType: 'PRENATAL')),
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
              Navigator.pop(context); // Close dialog
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

  Widget _buildGuideGrid() {
    final guides = [
      {
        'number': '1',
        'title': 'Schedule Your First Prenatal Visit',
        'description':
            'Book an appointment as soon as you find out you\'re pregnant.',
      },
      {
        'number': '2',
        'title': 'Attend Checkups',
        'description':
            'Follow your doctor\'s recommended prenatal visit schedule.',
      },
      {
        'number': '3',
        'title': 'Get Tests',
        'description':
            'Follow your doctor\'s advice for ultrasounds, labs, and screenings.',
      },
      {
        'number': '4',
        'title': 'Discuss Concerns',
        'description':
            'Share symptoms, medications, and lifestyle openly with your doctor.',
      },
      {
        'number': '5',
        'title': 'Follow Medical Advice',
        'description':
            'Take prescribed supplements, maintain healthy habits, and follow up on clinic instructions.',
      },
      {
        'number': '6',
        'title': 'Eat Nutritious Meals',
        'description':
            'Choose fruits, veggies, grains, and protein; limit processed foods.',
      },
      {
        'number': '7',
        'title': 'Take Prenatal Vitamins',
        'description': 'Take prescribed folic acid, iron, and calcium daily.',
      },
      {
        'number': '8',
        'title': 'Stay Hydrated & Active',
        'description': 'Drink water and do light daily exercise.',
      },
      {
        'number': '9',
        'title': 'Get Proper Rest',
        'description':
            'Sleep 7–9 hours, nap when needed, and rest on your side.',
      },
      {
        'number': '10',
        'title': 'Practice Safety',
        'description':
            'Avoid alcohol, smoking, and unsafe medicines; follow doctor\'s advice.',
      },
    ];

    return Wrap(
      spacing: 30,
      runSpacing: 30,
      children: guides.map((guide) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 250 - 120) / 2,
          child: _buildGuideCard(
            guide['number']!,
            guide['title']!,
            guide['description']!,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuideCard(String number, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number Circle
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFB8764F),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 22,
                  fontFamily: 'Bold',
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Regular',
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardAction({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 230,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
