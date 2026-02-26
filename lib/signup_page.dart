import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'scanner_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Logic Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _landSizeController = TextEditingController();

  String _selectedSoilType = 'Black Soil';
  String? _vId;
  bool _otpSent = false;
  bool _loading = false;

  // Agri Theme Colors
  final Color primaryGreen = const Color(0xFF2E7D32); // Deep Green
  final Color lightGreen = const Color(0xFFE8F5E9);   // Light Green background
  final Color accentBrown = const Color(0xFF795548);  // Earthy Brown

  // STEP 1: Send OTP
  void _sendOTP() async {
    if (_phoneController.text.length < 10) {
      _showSnackBar("Please enter a valid 10-digit number");
      return;
    }
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91${_phoneController.text.trim()}',
      verificationCompleted: (cred) => _registerInDB(cred),
      verificationFailed: (e) {
        setState(() => _loading = false);
        _showSnackBar("Error: ${e.message}");
      },
      codeSent: (id, _) => setState(() {
        _vId = id;
        _otpSent = true;
        _loading = false;
        _showSnackBar("OTP sent to +91 ${_phoneController.text}");
      }),
      codeAutoRetrievalTimeout: (id) => _vId = id,
    );
  }

  // STEP 2: Verify OTP
  void _verifyAndSignup() async {
    if (_otpController.text.isEmpty) {
      _showSnackBar("Please enter the 6-digit OTP");
      return;
    }
    setState(() => _loading = true);
    AuthCredential cred = PhoneAuthProvider.credential(
      verificationId: _vId!,
      smsCode: _otpController.text.trim(),
    );
    _registerInDB(cred);
  }

  // STEP 3: Save to Firestore
  void _registerInDB(AuthCredential cred) async {
    try {
      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      
      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'name': _nameController.text.trim(),
        'cropping_style': "", 
        'phone': '+91${_phoneController.text.trim()}',
        'soil_type': _selectedSoilType,
        'land_size': _landSizeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'iot_device_id': [], // NEW USER = NO DEVICE LINKED
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar("Welcome, ${_nameController.text}!");
      
      // Navigate to Scanner
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ScannerPage()));
    } catch (e) {
      setState(() => _loading = false);
      _showSnackBar("Registration Failed. Try again.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: accentBrown,
    ));
  }

  // Reusable Input Decoration from the Older UI
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header Section (Modern Green Box)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 80, bottom: 40, left: 20, right: 20),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("AgriSmart", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text("Create Farm Profile", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        Text("Individualized Advisory for your land", style: TextStyle(color: Colors.white60, fontSize: 14)),
                      ],
                    ),
                  ),

                  // Form Section (Card UI)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            TextField(controller: _nameController, decoration: _buildInputDecoration("Full Name", Icons.person)),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _phoneController,
                              enabled: !_otpSent,
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration("Mobile Number", Icons.phone).copyWith(prefixText: "+91 "),
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: 15),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration("Enter OTP", Icons.lock),
                              ),
                            ],
                            const SizedBox(height: 15),
                            TextField(controller: _descriptionController, decoration: _buildInputDecoration("Land Description", Icons.eco)),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _landSizeController,
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration("Land Size (Acres)", Icons.landscape),
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              value: _selectedSoilType,
                              decoration: _buildInputDecoration("Soil Type", Icons.layers),
                              items: ['Black Soil', 'Red Soil', 'Sandy Soil', 'Clay Soil']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _selectedSoilType = v!),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _otpSent ? _verifyAndSignup : _sendOTP,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  _otpSent ? "VERIFY & REGISTER" : "SEND OTP",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginPage())),
                              child: Text("Already a Farmer? Login here", style: TextStyle(color: accentBrown, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Agri Smart Advisor • Secured by Firebase", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}