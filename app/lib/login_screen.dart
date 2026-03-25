import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await _authService.login(_emailController.text, _passwordController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text("Welcome Back", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("Sign in to continue your health journey", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 60),
                  _buildTextField("Email Address", _emailController, Icons.email_outlined, false),
                  const SizedBox(height: 24),
                  _buildTextField("Password", _passwordController, Icons.lock_outline, true),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text("Forgot Password?", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 40),
                  _buildPrimaryButton("Login", _login),
                  const SizedBox(height: 32),
                  _buildFooter(),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _testConnectivity,
                    child: Text("Test Connection Status", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
        ],
      ),
    );
  }

  Future<void> _testConnectivity() async {
    setState(() => _loading = true);
    try {
      final url = "https://xowqknkxnbalzgapohoo.supabase.co/rest/v1/";
      print("DIAGNOSTIC: Pinging $url");
      final res = await http.get(Uri.parse(url), headers: {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhvd3Frbmt4bmJhbHpnYXBvaG9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5Njc2OTEsImV4cCI6MjA4OTU0MzY5MX0.dPUU8ffHfJRD-aiAvj9kkNqH5TSi88dpGOkBSPidGZQ"
      }).timeout(const Duration(seconds: 10));
      print("DIAGNOSTIC: Status: ${res.statusCode}");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Success: Stat ${res.statusCode}")));
    } catch (e) {
      print("DIAGNOSTIC: Failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Blocked: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildBackgroundDecor() {
    return Positioned(
      top: -150,
      left: -50,
      child: Container(
        width: 350,
        height: 350,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6C63FF).withOpacity(0.1)),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6C63FF).withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF6C63FF))),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 10,
          shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
        ),
        child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: GoogleFonts.outfit(color: Colors.grey)),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
          child: Text("Sign Up", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _selectedDate;
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _signUp() async {
    print("DEBUG: _signUp called");
    if (_nameController.text.isEmpty || _selectedDate == null) {
      print("DEBUG: Validation failed - Name or Date missing");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all profile fields")));
      return;
    }

    setState(() => _loading = true);
    try {
      print("DEBUG: Calling _authService.signUp...");
      final response = await _authService.signUp(
        _emailController.text, 
        _passwordController.text
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw "Connection timed out. Check your internet or Supabase settings.";
      });
      print("DEBUG: Auth Sign-up response: ${response.user?.id}");
      
      if (response.user != null) {
        try {
          // Save profile metadata
          await Supabase.instance.client.from('profiles').insert({
            'id': response.user!.id,
            'full_name': _nameController.text,
            'age': int.tryParse(_ageController.text) ?? 0,
            'birth_date': _selectedDate?.toIso8601String().split('T')[0],
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Account created! If you enabled email verification, check your inbox.")),
            );
            Navigator.pop(context);
          }
        } catch (profileError) {
          debugPrint("Profile insert error: $profileError");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Account created, but profile failed: $profileError")),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Sign Up Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sign Up Failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text("Create Account", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Join our health community today", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 40),
            _buildTextField("Full Name", _nameController, Icons.person_outline, false),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildTextField("Age", _ageController, Icons.calendar_month, false, isNumber: true)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Birth Date", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cake_outlined, color: const Color(0xFF6C63FF).withOpacity(0.6), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedDate == null ? "Select" : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField("Email Address", _emailController, Icons.email_outlined, false),
            const SizedBox(height: 20),
            _buildTextField("Password", _passwordController, Icons.lock_outline, true),
            const SizedBox(height: 40),
            _buildPrimaryButton("Create Account", _signUp),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isPassword, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6C63FF).withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF6C63FF))),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 10,
          shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
        ),
        child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
