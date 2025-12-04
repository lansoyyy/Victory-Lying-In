import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_prenatal_records_screen.dart';
import 'admin_postnatal_records_screen.dart';
import 'admin_appointment_scheduling_screen.dart';
import 'admin_transfer_requests_screen.dart';
import '../auth/home_screen.dart';

class AdminEducationalCmsScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const AdminEducationalCmsScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<AdminEducationalCmsScreen> createState() =>
      _AdminEducationalCmsScreenState();
}

class _AdminEducationalCmsScreenState extends State<AdminEducationalCmsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String _category = 'PRENATAL';
  final List<String> _selectedTags = [];
  bool _isSaving = false;

  final List<String> _tags = const [
    '1st Trimester',
    '2nd Trimester',
    '3rd Trimester',
    'High Risk-Diabetes',
    'High Risk-Hypertension',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveArticle() async {
    if (_isSaving) return;

    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', Colors.red);
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      _showSnackBar('Please enter article content', Colors.red);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('educationalArticles').add({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'category': _category,
        'targetTags': _selectedTags,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userName,
        'published': true,
      });

      _titleController.clear();
      _bodyController.clear();
      _selectedTags.clear();

      if (mounted) {
        setState(() {});
        _showSnackBar('Article saved successfully', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to save article: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Regular'),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Educational Content Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Bold',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create and manage educational articles for prenatal and postnatal patients.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildArticleForm(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 3,
                          child: _buildArticleList(),
                        ),
                      ],
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
          _buildMenuItem('PRENATAL PATIENT\nRECORD', false),
          _buildMenuItem('POSTNATAL PATIENT\nRECORD', false),
          _buildMenuItem('APPOINTMENT\nSCHEDULING', false),
          _buildMenuItem('TRANSFER\nREQUESTS', false),
          _buildMenuItem('EDUCATIONAL CMS', true),
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
      case 'PRENATAL PATIENT\nRECORD':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPrenatalRecordsScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
      case 'POSTNATAL PATIENT\nRECORD':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPostnatalRecordsScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
      case 'APPOINTMENT\nSCHEDULING':
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
      case 'TRANSFER\nREQUESTS':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminTransferRequestsScreen(
              userRole: widget.userRole,
              userName: widget.userName,
            ),
          ),
        );
        break;
    }
  }

  Widget _buildArticleForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Article',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                labelText: 'Content / Body',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'PRENATAL',
                      child: Text('Prenatal'),
                    ),
                    DropdownMenuItem(
                      value: 'POSTNATAL',
                      child: Text('Postnatal'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _category = value ?? 'PRENATAL';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTagSelector(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveArticle,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Article',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Bold',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSelector() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target Audience Tags',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags.map((tag) {
              final bool isSelected = _selectedTags.contains(tag);
              return ChoiceChip(
                label: Text(
                  tag,
                  style: const TextStyle(fontSize: 11, fontFamily: 'Regular'),
                ),
                selected: isSelected,
                selectedColor: primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Existing Articles',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('educationalArticles')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No articles yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title']?.toString() ?? '';
                    final category = data['category']?.toString() ?? '';
                    final tags = (data['targetTags'] as List?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Bold',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: category == 'POSTNATAL'
                                    ? Colors.blue.shade50
                                    : Colors.pink.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Bold',
                                  color: category == 'POSTNATAL'
                                      ? Colors.blue.shade700
                                      : Colors.pink.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: tags
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
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
                    );
                  },
                );
              },
            ),
          ),
        ],
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
