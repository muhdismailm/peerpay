import 'package:expense_tracker/login.dart';
import 'package:expense_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_agreeToTerms) {
      _showToast("Please agree to terms and conditions");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showToast("Passwords don't match");
      return;
    }

    if (_passwordController.text.length < 6) {
      _showToast("Password must be at least 6 characters");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await userCredential.user?.updateDisplayName(_fullNameController.text.trim());

      // ✅ Store user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BankingApp()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Sign up failed";
      if (e.code == 'weak-password') {
        errorMessage = "The password provided is too weak";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "The account already exists for that email";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is invalid";
      }
      _showToast(errorMessage);
    } catch (e) {
      _showToast("An error occurred. Please try again");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final primaryColor = const Color(0xFF5FBB62);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to get started with banking',
                  style: TextStyle(
                    fontSize: 16,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 32),

                // Full Name
                _buildInputField(
                  label: 'Full Name',
                  hint: 'John Doe',
                  controller: _fullNameController,
                  icon: Icons.person_outline,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  backgroundColor: backgroundColor!,
                  isDarkMode: isDarkMode,
                ),

                const SizedBox(height: 16),

                // Email
                _buildInputField(
                  label: 'Email',
                  hint: 'john@example.com',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  backgroundColor: backgroundColor,
                  isDarkMode: isDarkMode,
                ),

                const SizedBox(height: 16),

                // Password
                _buildInputField(
                  label: 'Password',
                  hint: 'Enter password',
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  toggleObscure: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  backgroundColor: backgroundColor,
                  isDarkMode: isDarkMode,
                ),

                const SizedBox(height: 16),

                // Confirm Password
                _buildInputField(
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  controller: _confirmPasswordController,
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscureConfirmPassword,
                  toggleObscure: () => setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  }),
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  backgroundColor: backgroundColor,
                  isDarkMode: isDarkMode,
                ),

                const SizedBox(height: 16),

                // Terms Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'I agree to the terms and conditions',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: primaryColor.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required Color textColor,
    required Color? secondaryTextColor,
    required Color backgroundColor,
    required bool isDarkMode,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: secondaryTextColor),
              prefixIcon: Icon(icon, color: secondaryTextColor),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: secondaryTextColor,
                      ),
                      onPressed: toggleObscure,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
