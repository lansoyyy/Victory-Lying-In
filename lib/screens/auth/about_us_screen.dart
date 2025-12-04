import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import 'home_screen.dart';
import 'contact_us_screen.dart';
import 'services_screen.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
                horizontal: screenWidth * 0.08,
                vertical: 60,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title
                  const Text(
                    'ABOUT US',
                    style: TextStyle(
                      fontSize: 42,
                      fontFamily: 'Bold',
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 100,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, secondary],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Staff Profiles + Mission & Vision
                  _buildAboutSection(),
                  const SizedBox(height: 60),

                  // Services Overview
                  _buildServicesOverview(),
                ],
              ),
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
              _buildNavItem('HOME', false),
              _buildNavItem('ABOUT US', true),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 'ABOUT US':
        // Already on about us screen
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

  Widget _buildAboutSection() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/figure.png',
                  height: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'WELCOME TO VICTORY LYING-IN CENTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'Bold',
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          const Text(
            'OUR MISSION',
            style: TextStyle(
              fontSize: 22,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The Victory Lying-in Center is committed in serving the community by providing high quality care and medical services in a most affordable and compassionate manner.',
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Regular',
              color: Colors.black87,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'OUR VISION',
            style: TextStyle(
              fontSize: 22,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The Victory Lying-in Center envisions to be a leading provider of excellent health care to achieve the highest level of quality in Maternal and Child Health care and promote the highest standard of obstetric, gynecologic and reproductive health through personalize clinical care to our patient',
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Regular',
              color: Colors.black87,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 30,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: const [
              _StaffProfileCard(
                name: 'OB - Maureen R. Higoy MD',
                role: 'Obstetrician-Gynecologist',
              ),
              _StaffProfileCard(
                name: 'Girlie Hagos',
                role: 'Staff',
              ),
              _StaffProfileCard(
                name: 'Aprilyn Ay-Ayen',
                role: 'Staff',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OUR SERVICES',
          style: TextStyle(
            fontSize: 32,
            fontFamily: 'Bold',
            color: primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            _buildServiceCard(
              'assets/images/ob-gyne.png',
              'OB-GYNE',
              'Comprehensive obstetrics and gynecology services for women\'s health',
            ),
            const SizedBox(width: 30),
            _buildServiceCard(
              'assets/images/ultra sound.png',
              'ULTRASOUND',
              'Advanced ultrasound imaging for prenatal monitoring and diagnostics',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCard(String iconPath, String title, String description) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(30),
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Bold',
                color: primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
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

class _StaffProfileCard extends StatelessWidget {
  final String name;
  final String role;

  const _StaffProfileCard({
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 46,
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
