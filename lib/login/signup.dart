import 'dart:math';
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
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showToast("Please agree to terms and conditions");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await userCredential.user?.updateDisplayName(_fullNameController.text.trim());

      await _storeUserData(userCredential.user!);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BankingApp()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showToast("An error occurred. Please try again");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _storeUserData(User user) async {
    String fullName = _fullNameController.text.trim();
    String prefix = fullName.replaceAll(RegExp(r'\s+'), '').toUpperCase().padRight(4, 'X').substring(0, 4);
    String customUid = await _generateUniqueCustomUID(prefix);

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'customUid': customUid,
      'fullName': fullName,
      'email': _emailController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'accountStatus': 'active',
      'profileComplete': false,
      'preferences': {
        'theme': 'system',
        'currency': 'USD',
      },
    });
  }

  Future<String> _generateUniqueCustomUID(String prefix) async {
    final random = Random();
    String customUid;

    while (true) {
      int number = random.nextInt(900) + 100;
      customUid = '$prefix$number';

      final existing = await _firestore
          .collection('users')
          .where('customUid', isEqualTo: customUid)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        break;
      }
    }

    return customUid;
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage = "Sign up failed";
    switch (e.code) {
      case 'weak-password':
        errorMessage = "Password is too weak (min 6 characters)";
        break;
      case 'email-already-in-use':
        errorMessage = "Account already exists for this email";
        break;
      case 'invalid-email':
        errorMessage = "Invalid email address";
        break;
      case 'operation-not-allowed':
        errorMessage = "Email/password accounts are not enabled";
        break;
    }
    _showToast(errorMessage);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = _getColors(isDarkMode);

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),
                _buildTextFormField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'John Doe',
                  icon: Icons.person_outline,
                  validator: (value) => value!.isEmpty ? 'Enter your name' : null,
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'your@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => 
                      !value!.contains('@') ? 'Enter valid email' : null,
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  toggleObscure: () => setState(
                      () => _obscurePassword = !_obscurePassword),
                  validator: (value) => 
                      value!.length < 6 ? 'Minimum 6 characters' : null,
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscureConfirmPassword,
                  toggleObscure: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  validator: (value) => value != _passwordController.text 
                      ? 'Passwords do not match' : null,
                  colors: colors,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) => 
                          setState(() => _agreeToTerms = value ?? false),
                      activeColor: colors.primary,
                    ),
                    Expanded(
                      child: Text(
                        'I agree to terms and privacy policy',
                        style: TextStyle(color: colors.secondaryText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      disabledBackgroundColor: colors.primary.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required FormFieldValidator<String> validator,
    required _FormColors colors,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.fieldBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: colors.boxShadow,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: colors.text),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: colors.secondaryText),
              prefixIcon: Icon(icon, color: colors.secondaryText),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: colors.secondaryText,
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

  _FormColors _getColors(bool isDarkMode) {
    return _FormColors(
      text: isDarkMode ? Colors.white : Colors.black,
      secondaryText: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
      primary: const Color(0xFF5FBB62),
      fieldBackground: isDarkMode ? Colors.grey[900]! : Colors.white,
      scaffoldBackground: isDarkMode ? Colors.black : Colors.grey[100]!,
      boxShadow: isDarkMode
          ? []
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
    );
  }
}

class _FormColors {
  final Color text;
  final Color secondaryText;
  final Color primary;
  final Color fieldBackground;
  final Color scaffoldBackground;
  final List<BoxShadow> boxShadow;

  _FormColors({
    required this.text,
    required this.secondaryText,
    required this.primary,
    required this.fieldBackground,
    required this.scaffoldBackground,
    required this.boxShadow,
  });
}
