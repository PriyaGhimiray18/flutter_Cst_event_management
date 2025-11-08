import 'package:flutter/material.dart';
import '../helpers/supabase_auth_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  SupabaseAuthHelper? _authHelper;

  @override
  void initState() {
    super.initState();
    _initAuthHelper();
  }


  Future<void> _initAuthHelper() async {
    _authHelper = await SupabaseAuthHelper.getInstance();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;

    // Ensure auth helper is ready even if user taps quickly after opening screen
    if (_authHelper == null) {
      await _initAuthHelper();
      if (_authHelper == null) {
        _showSnackBar('Initializing, please try again in a moment');
        return;
      }
    }

    // Validate input
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _loading = true);

    try {
      await _authHelper!.signIn(email, password);
      
      if (!mounted) return;

      // Re-fetch from database to ensure we have the latest role
      final refreshedUser = await _authHelper!.getCurrentUser();

      // Check user role and redirect accordingly
      if (refreshedUser != null && refreshedUser.role == 'admin') {
        // Navigate to Admin Dashboard
        Navigator.pushReplacementNamed(context, '/admin');
        _showSnackBar('Login successful', isError: false);
      } else {
        // Navigate to Home Screen (User Dashboard)
        Navigator.pushReplacementNamed(context, '/home');
        _showSnackBar('Login successful', isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Authentication failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section with Logo and Title
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.event_available,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CST Events',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section with Form
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Text(
                        'Login',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your credentials to continue',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 24),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/signup'),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
            ),
          ],
        ),
      ),
    );
  }
}
