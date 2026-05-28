import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/containment_utils.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'user';

  @override
  void initState() {
    super.initState();
    ContainmentUtils().activateContainment(
      onScreenshotDetected: () {
        SecurityWarning.showScreenshotWarning(context);
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    ContainmentUtils().deactivateContainment();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      role: _selectedRole,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REQUEST ACCESS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                
                // Title
                const Text(
                  'JOIN AEGIS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8ECF2),
                    letterSpacing: 3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'ESTABLISH SECURE CLEARANCE',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00C6AE),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Registration Form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name Field
                        SecureTextField(
                          controller: _nameController,
                          hintText: 'Full Name',
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline),
                            labelText: 'Operative Name',
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Email Field
                        SecureTextField(
                          controller: _emailController,
                          hintText: 'user@defense.mil',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Email is required';
                            if (!value.contains('@')) return 'Invalid email format';
                            return null;
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined),
                            labelText: 'Clearance Email',
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Role Selection
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          dropdownColor: const Color(0xFF182842),
                          style: const TextStyle(color: Color(0xFFE8ECF2), fontSize: 14),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.shield_outlined),
                            labelText: 'Clearance Level',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('Defense Personnel / Family'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Group Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'hq_admin',
                              child: Text('HQ Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        SecureTextField(
                          controller: _passwordController,
                          hintText: 'Enter passphrase',
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Passphrase is required';
                            if (value.length < 6) return 'Passphrase too short (min 6 chars)';
                            return null;
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: 'Passphrase',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF8A9AB5),
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
                        
                        // Confirm Password Field
                        SecureTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirm passphrase',
                          obscureText: _obscureConfirmPassword,
                          validator: (value) {
                            if (value != _passwordController.text) return 'Passphrases do not match';
                            return null;
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: 'Confirm Passphrase',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF8A9AB5),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Register Button
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            return ElevatedButton(
                              onPressed: authProvider.isLoading ? null : _register,
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF0A1628),
                                        ),
                                      ),
                                    )
                                  : const Text('ESTABLISH CREDENTIALS'),
                            );
                          },
                        ),
                        
                        if (Provider.of<AuthProvider>(context).error != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A5F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
                            ),
                            child: Text(
                              Provider.of<AuthProvider>(context).error!,
                              style: const TextStyle(
                                color: Color(0xFFFF5A5F),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Back to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Clearance active? ",
                      style: TextStyle(color: Color(0xFF8A9AB5)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Authenticate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
