import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart'; 
class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _landSizeController = TextEditingController();

  String _selectedSoilType = 'Black Soil';
  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;

  // Agri Theme Colors
  final Color primaryGreen = const Color(0xFF2E7D32); // Deep Green
  final Color lightGreen = const Color(0xFFE8F5E9);   // Very Light Green background
  final Color accentBrown = const Color(0xFF795548);  // Earthy Brown

  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      _showSnackBar("Please enter a valid phone number");
      return;
    }
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91${_phoneController.text.trim()}',
      verificationCompleted: (PhoneAuthCredential credential) async => await _signInAndSaveData(credential),
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showSnackBar("Error: ${e.message}");
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
        _showSnackBar("OTP sent to +91${_phoneController.text}");
      },
      codeAutoRetrievalTimeout: (String vId) => _verificationId = vId,
    );
  }

  Future<void> _verifyAndRegister() async {
    if (_otpController.text.isEmpty) {
      _showSnackBar("Please enter the 6-digit OTP");
      return;
    }
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _signInAndSaveData(credential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Invalid OTP. Please try again.");
    }
  }

  Future<void> _signInAndSaveData(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'phone': '+91${_phoneController.text.trim()}',
          'description': _descriptionController.text.trim(),
          'soil_type': _selectedSoilType,
          'land_size': _landSizeController.text.trim(),
          'iot_device_id': '',
          'created_at': FieldValue.serverTimestamp(),
        });
        _showSnackBar("Welcome, ${_nameController.text}!");
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: accentBrown,
    ));
  }

  // Reusable Input Decoration
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header Section
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

                  // Form Section
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
                              enabled: !_isOtpSent,
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration("Mobile Number", Icons.phone).copyWith(prefixText: "+91 "),
                            ),
                            if (_isOtpSent) ...[
                              const SizedBox(height: 15),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration("Enter 6-Digit OTP", Icons.lock_outline),
                              ),
                            ],
                            const SizedBox(height: 15),
                            TextField(controller: _descriptionController, decoration: _buildInputDecoration("Land Description", Icons.eco_outlined)),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _landSizeController,
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration("Land Size (Acres)", Icons.straighten),
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              value: _selectedSoilType,
                              decoration: _buildInputDecoration("Soil Type", Icons.layers_outlined),
                              items: ['Black Soil', 'Red Soil', 'Sandy Soil', 'Clay Soil']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _selectedSoilType = v!),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isOtpSent ? _verifyAndRegister : _sendOTP,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                child: Text(
                                  _isOtpSent ? "VERIFY & REGISTER" : "SEND OTP",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Agri Smart", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}