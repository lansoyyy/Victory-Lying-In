import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import 'home_screen.dart';
import 'about_us_screen.dart';
import 'services_screen.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchTelephone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (!await launchUrl(phoneUri)) {
      _showErrorDialog('Could not launch phone dialer');
    }
  }

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
              child: Center(
                child: _buildAddressSection(),
              ),
            ),
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
              _buildNavItem('ABOUT US', false),
              _buildNavItem('SERVICES', false),
              _buildNavItem('CONTACT US', true),
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
        // Already on contact us screen
        break;
    }
  }

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Have Question or Concerns?',
          style: TextStyle(
            fontSize: 32,
            fontFamily: 'Bold',
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 30),

        // Form Card
        Container(
          padding: const EdgeInsets.all(35),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary.withOpacity(0.85), secondary.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name Field
              _buildTextField(
                controller: _nameController,
                hintText: 'Name',
              ),
              const SizedBox(height: 20),

              // Email Field
              _buildTextField(
                controller: _emailController,
                hintText: 'Email Address',
              ),
              const SizedBox(height: 20),

              // Contact Number Field
              _buildTextField(
                controller: _contactController,
                hintText: 'Contact Number',
              ),
              const SizedBox(height: 20),

              // Message Field
              _buildTextField(
                controller: _messageController,
                hintText: 'Message',
                maxLines: 5,
              ),
              const SizedBox(height: 25),

              // Send Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle send message
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Bold',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.black,
        fontFamily: 'Regular',
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade600,
          fontFamily: 'Regular',
          fontSize: 15,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: maxLines > 1 ? 15 : 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            const Text(
              'CONTACT INFORMATION',
              style: TextStyle(
                fontSize: 32,
                fontFamily: 'Bold',
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 30),

            // Contact Information Card
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withOpacity(0.85),
                    secondary.withOpacity(0.85)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SizedBox(
                width: 400,
                child: Column(
                  children: [
                    // Email
                    _buildContactItem(
                      icon: Icons.email,
                      label: 'Email',
                      value: 'victorylying@yahoo.com',
                      onTap: () => _launchEmail('victorylying@yahoo.com'),
                    ),
                    const SizedBox(height: 20),

                    // Instagram
                    _buildContactItem(
                      icon: Icons.camera_alt,
                      label: 'Instagram',
                      value: '@victory_lyingincenter',
                      onTap: () => _launchInstagram('victory_lyingincenter'),
                    ),
                    const SizedBox(height: 20),

                    // Facebook
                    _buildContactItem(
                      icon: Icons.facebook,
                      label: 'Facebook',
                      value: 'Victory Lying-In Center',
                      onTap: () => _launchFacebook(),
                    ),
                    const SizedBox(height: 20),

                    // Telephone
                    _buildContactItem(
                      icon: Icons.phone,
                      label: 'Telephone',
                      value: '0956 879 1685',
                      onTap: () => _launchTelephone('09568791685'),
                    ),
                  ],
                ),
              ),
            ),

            // Map Section
          ],
        ),
        SizedBox(
          width: 20,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'ADDRESS & LOCATION',
              style: TextStyle(
                fontSize: 32,
                fontFamily: 'Bold',
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '2104-2114 Dimasalang St, Santa Cruz, Manila, 1008 Metro Manila',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Regular',
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            // Map Image
            Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/map.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if map image doesn't exist
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Map Location',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontFamily: 'Medium',
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontFamily: 'Medium',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'Bold',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: primary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (!await launchUrl(emailUri)) {
      _showErrorDialog('Could not launch email app');
    }
  }

  Future<void> _launchInstagram(String username) async {
    final Uri instagramUri = Uri.parse('instagram://user/?username=$username');
    final Uri webUri = Uri.parse('https://www.instagram.com/$username');

    if (!await launchUrl(instagramUri)) {
      // If app is not installed, try to open in web browser
      if (!await launchUrl(webUri)) {
        _showErrorDialog('Could not launch Instagram');
      }
    }
  }

  Future<void> _launchFacebook() async {
    const String facebookUrl = 'https://www.facebook.com/VictoryLyingInCenter';
    final Uri facebookUri = Uri.parse(facebookUrl);

    if (!await launchUrl(facebookUri)) {
      _showErrorDialog('Could not launch Facebook');
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
}
