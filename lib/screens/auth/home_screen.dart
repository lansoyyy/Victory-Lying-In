import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import 'contact_us_screen.dart';
import 'about_us_screen.dart';
import 'services_screen.dart';
import 'signup_screen.dart';
import '../prenatal_dashboard_screen.dart';
import '../postnatal_dashboard_screen.dart';
import '../../widgets/forgot_password_dialog.dart';
import '../../widgets/admin_login_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
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
        // Already on home screen
        break;
      case 'ABOUT US':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutUsScreen()),
        );
        break;
      case 'SERVICES':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServicesScreen()),
        );
        break;

      case 'CONTACT US':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactUsScreen()),
        );
        break;
    }
  }

  Future<void> _handleSignIn() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your email address');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      await user?.reload();

      if (user == null || !user.emailVerified) {
        setState(() {
          _isLoading = false;
        });

        await _auth.signOut();
        _showErrorDialog(
          'Your email is not verified yet. Please check your inbox and verify your email before signing in.',
        );
        return;
      }

      // Get user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      setState(() {
        _isLoading = false;
      });

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String patientType = userData['patientType'] ?? 'PRENATAL';
        String role = userData['role'] ?? 'patient';

        // Check if user is admin (should use admin login)
        if (role == 'admin') {
          await _auth.signOut();
          _showErrorDialog('Please use Admin Login for admin accounts.');
          return;
        }

        // Navigate to appropriate dashboard based on patient type from Firestore
        if (mounted) {
          if (patientType == 'PRENATAL') {
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
        }
      } else {
        // User authenticated but no Firestore data - create basic record
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'name': userCredential.user!.email?.split('@')[0] ?? 'User',
          'patientType': 'PRENATAL',
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'patient',
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PrenatalDashboardScreen(
                openPersonalDetailsOnLoad: true,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'An error occurred';
      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled';
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
                height: screenHeight * 0.5,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              // Get to Know Us Section
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.1),
                        secondary.withOpacity(0.1)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: primary.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Get to Know Us',
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'Bold',
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Watch our story and discover the care we provide',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Regular',
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Video Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, secondary],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final Uri videoUri = Uri.parse(
                                'https://web.facebook.com/share/v/1Gn41z66e8/?mibextid=adiEgM');
                            if (!await launchUrl(videoUri)) {
                              _showErrorDialog('Could not launch video');
                            }
                          },
                          icon: const Icon(Icons.play_circle_filled, size: 28),
                          label: const Text(
                            'Watch Our Story',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
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
        ),

        // Right Section - Sign In Form
        Expanded(
          flex: 3,
          child: _buildSignInCard(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(double screenWidth, double screenHeight) {
    return Column(
      children: [
        _buildSignInCard(),
        const SizedBox(height: 40),
        Image.asset(
          'assets/images/figure.png',
          height: screenHeight * 0.25,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        // Get to Know Us Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary.withOpacity(0.1), secondary.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              const Text(
                'Get to Know Us',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Bold',
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Watch our story and discover the care we provide',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              // Video Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, secondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri videoUri = Uri.parse(
                        'https://web.facebook.com/share/v/1Gn41z66e8/?mibextid=adiEgM');
                    if (!await launchUrl(videoUri)) {
                      _showErrorDialog('Could not launch video');
                    }
                  },
                  icon: const Icon(Icons.play_circle_filled, size: 24),
                  label: const Text(
                    'Watch Our Story',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Bold',
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  Widget _buildSignInCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'WELCOME ',
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Regular',
                  color: Colors.black,
                ),
              ),
              Icon(
                Icons.favorite_border,
                color: Colors.grey.shade700,
                size: 24,
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

          // Sign In Title
          Text(
            'SIGN IN',
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
          const SizedBox(height: 10),

          // Forget Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ForgotPasswordDialog(),
                );
              },
              child: const Text(
                'Forget Password?',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Regular',
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Sign In Button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSignIn,
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
                    'SIGN IN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Bold',
                      letterSpacing: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // Create Account Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'New here? ',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Regular',
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SignupScreen()),
                  );
                },
                child: Text(
                  'Create an Account',
                  style: TextStyle(
                    color: primary,
                    fontFamily: 'Medium',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Admin Button
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AdminLoginDialog(),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'ADMIN',
              style: TextStyle(
                color: primary,
                fontSize: 14,
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
