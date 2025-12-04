import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import 'contact_us_screen.dart';
import 'about_us_screen.dart';
import 'services_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  DateTime? _dob;
  String _selectedGender = 'PRENATAL';
  bool _isLoading = false;
  bool _obscurePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Navigation Bar
            _buildHeader(),

            // Main Content
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: 40,
              ),
              child: screenWidth > 900
                  ? _buildDesktopLayout(screenWidth, screenHeight)
                  : _buildMobileLayout(screenWidth, screenHeight),
            ),

            // Footer Section
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          const Text(
            'VICTORY LYING IN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'Bold',
              letterSpacing: 1.2,
            ),
          ),

          // Navigation Menu
          Wrap(
            spacing: 40,
            children: [
              _buildNavItem('HOME', true),
              _buildNavItem('ABOUT US', false),
              _buildNavItem('SERVICES', false),
              _buildNavItem('CONTACT US', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String title, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _handleNavigation(title);
        },
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: isActive ? 'Bold' : 'Medium',
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _handleNavigation(String title) {
    switch (title) {
      case 'HOME':
        Navigator.pop(context);
        break;
      case 'ABOUT US':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AboutUsScreen()),
        );
        break;
      case 'SERVICES':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ServicesScreen()),
        );
        break;
      case 'CONTACT US':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ContactUsScreen()),
        );
        break;
    }
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

  Future<void> _handleSignup() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your email address');
      return;
    }
    if (_fullNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your full name');
      return;
    }
    if (_contactNumberController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your contact number');
      return;
    }
    if (_dob == null) {
      _showErrorDialog('Please select your date of birth');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a password');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showErrorDialog('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int age = _calculateAge(_dob!);

      // Create user with Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'firstName': _fullNameController.text.trim(),
        'lastName': '',
        'name': _fullNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'address': '',
        'age': age,
        'dob': Timestamp.fromDate(_dob!),
        'patientType': _selectedGender,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'patient',
        'profileCompleted': false,
      });

      try {
        await userCredential.user!.sendEmailVerification();
      } catch (_) {
        // ignore email verification errors, user can request again later
      }

      setState(() {
        _isLoading = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Account created successfully! Please verify your email, then sign in.',
              style: TextStyle(fontFamily: 'Regular'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to login
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'An error occurred';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for this email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }

      _showErrorDialog(errorMessage);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('An unexpected error occurred. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Error',
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

  Widget _buildDesktopLayout(double screenWidth, double screenHeight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Section - Services
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServiceItem(
                'assets/images/ob-gyne.png',
                'OB - GYNE',
              ),
              const SizedBox(height: 30),
              _buildServiceItem(
                'assets/images/ultra sound.png',
                'ULTRA SOUND',
              ),
            ],
          ),
        ),

        // Center Section - Illustration
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Image.asset(
                'assets/images/figure.png',
                height: screenHeight * 0.6,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),

        // Right Section - Register Form
        Expanded(
          flex: 3,
          child: _buildRegisterCard(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(double screenWidth, double screenHeight) {
    return Column(
      children: [
        _buildRegisterCard(),
        const SizedBox(height: 20),
        Image.asset(
          'assets/images/figure.png',
          height: screenHeight * 0.3,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        _buildServiceItem('assets/images/ob-gyne.png', 'OB - GYNE'),
        const SizedBox(height: 20),
        _buildServiceItem('assets/images/ultra sound.png', 'ULTRA SOUND'),
      ],
    );
  }

  Widget _buildServiceItem(String iconPath, String title) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: orangePallete,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(18),
          child: Image.asset(
            iconPath,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontFamily: 'Bold',
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'WELCOME',
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Regular',
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'BELOVE PATIENT',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontFamily: 'Bold',
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 30),

          // Register Title
          Text(
            'REGISTER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Bold',
              color: primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 25),

          // Email Field
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'Email address',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'Regular',
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Full Name Field
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              hintText: 'Full Name',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'Regular',
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Date of Birth Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date of Birth (DOB)',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Regular',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final initial =
                      _dob ?? DateTime(now.year - 25, now.month, now.day);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(now.year - 60),
                    lastDate: now,
                  );
                  if (picked != null) {
                    setState(() {
                      _dob = picked;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _dob == null
                            ? 'Select Date of Birth'
                            : '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}',
                        style: TextStyle(
                          color: _dob == null
                              ? Colors.grey.shade600
                              : Colors.black,
                          fontFamily: 'Regular',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Contact Number Field
          TextField(
            controller: _contactNumberController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Contact Number',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'Regular',
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // (Age will be calculated from DOB and stored in profile)
          // No direct age field here.

          // Password Field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'Regular',
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Gender Selection
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Radio<String>(
                        value: 'PRENATAL',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                        activeColor: primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'PRENATAL',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Regular',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Radio<String>(
                        value: 'POSTNATAL',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                        activeColor: primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'POSTNATAL',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Regular',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // Go to Sign In Button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                    'SIGN UP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Bold',
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: const Text(
        'We care about your health\nand well - being',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontFamily: 'Bold',
          height: 1.3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
