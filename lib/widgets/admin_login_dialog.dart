import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maternity_clinic/screens/admin/admin_dashboard_screen.dart';

import '../utils/colors.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Hardcoded user credentials
  final Map<String, Map<String, String>> _userCredentials = {
    'admin': {'password': 'admin123', 'role': 'admin', 'name': 'Administrator'},
    'nurse1': {'password': 'nurse123', 'role': 'nurse', 'name': 'Nurse 1'},
    'nurse2': {'password': 'nurse123', 'role': 'nurse', 'name': 'Nurse 2'},
  };

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter both username and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate authentication delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_userCredentials.containsKey(username) &&
          _userCredentials[username]?['password'] == password) {
        // Authentication successful
        final userData = _userCredentials[username]!;
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(
              userRole: userData['role']!,
              userName: userData['name']!,
            ),
          ),
        );
      } else {
        // Authentication failed
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Invalid username or password');
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Login Error',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Regular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: primary, fontFamily: 'Bold'),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Reset Staff/Admin Password',
                style: TextStyle(fontFamily: 'Bold'),
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Username',
                      style: TextStyle(fontSize: 13, fontFamily: 'Regular'),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'New Password',
                      style: TextStyle(fontSize: 13, fontFamily: 'Regular'),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Confirm New Password',
                      style: TextStyle(fontSize: 13, fontFamily: 'Regular'),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          final username =
                              usernameController.text.trim().toLowerCase();
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword =
                              confirmPasswordController.text.trim();

                          if (username.isEmpty ||
                              newPassword.isEmpty ||
                              confirmPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'New password and confirmation do not match'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setStateDialog(() {
                            isSaving = true;
                          });

                          try {
                            final docRef = _firestore
                                .collection('staffAccounts')
                                .doc(username);
                            final snap = await docRef.get();
                            if (!snap.exists) {
                              setStateDialog(() {
                                isSaving = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Username not found'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await docRef.update({
                              'password': newPassword,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password updated. Please login with your new password.',
                                  style: TextStyle(fontFamily: 'Regular'),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setStateDialog(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to update password. Try again.'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontFamily: 'Bold'),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(35),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Close Button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 10),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 25),

              // Title
              Text(
                'Admin Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Bold',
                  color: primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'Access the administrative dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),

              // Username Field
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontFamily: 'Regular',
                    fontSize: 14,
                  ),
                  hintText: 'Enter admin username',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontFamily: 'Regular',
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: primary,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontFamily: 'Regular',
                    fontSize: 14,
                  ),
                  hintText: 'Enter admin password',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontFamily: 'Regular',
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: primary,
                    size: 22,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Bold',
                          letterSpacing: 0.5,
                        ),
                      ),
              ),

              const SizedBox(height: 15),

              // Back to Patient Login
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Back to Patient Login',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontFamily: 'Medium',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
