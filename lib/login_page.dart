import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'scanner_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  
  String? _vId;
  bool _otpSent = false;
  bool _loading = false;

  // Agri Theme Colors (Matching Signup Page)
  final Color primaryGreen = const Color(0xFF2E7D32); // Deep Green
  final Color lightGreen = const Color(0xFFE8F5E9);   // Light Green background
  final Color accentBrown = const Color(0xFF795548);  // Earthy Brown

  // STEP 1: Check if phone exists in DB before sending OTP
  void _checkFarmerAndSendOTP() async {
    if (_phone.text.length < 10) {
      _showSnackBar("Please enter a valid 10-digit number");
      return;
    }

    setState(() => _loading = true);
    String fullPhone = "+91${_phone.text.trim()}";

    // Query Firestore to see if the farmer is already registered
    var userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: fullPhone)
        .get();

    if (userQuery.docs.isEmpty) {
      setState(() => _loading = false);
      _showSnackBar("Account not found. Please register first.", isError: true);
    } else {
      // User Exists -> Proceed to Firebase OTP
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (cred) => _verifyAndRoute(cred),
        verificationFailed: (e) {
          setState(() => _loading = false);
          _showSnackBar("Error: ${e.message}", isError: true);
        },
        codeSent: (id, _) => setState(() { 
          _vId = id; 
          _otpSent = true; 
          _loading = false; 
          _showSnackBar("OTP sent to +91 ${_phone.text}");
        }),
        codeAutoRetrievalTimeout: (id) => _vId = id,
      );
    }
  }

  void _verifyOTPManual() async {
    if (_otp.text.isEmpty) {
      _showSnackBar("Please enter the 6-digit OTP");
      return;
    }
    setState(() => _loading = true);
    AuthCredential cred = PhoneAuthProvider.credential(verificationId: _vId!, smsCode: _otp.text.trim());
    _verifyAndRoute(cred);
  }

  // STEP 2: Final Routing based on Device ID
  void _verifyAndRoute(AuthCredential cred) async {
    try {
      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      String uid = userCred.user!.uid;

      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String deviceId = doc['iot_device_id'] ?? "";

      if (!mounted) return;

      if (deviceId.isNotEmpty) {
        // ID EXISTS: Go to Dashboard
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => DashboardPage()), (route) => false);
      } else {
        // NO ID: Go to Scanner
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ScannerPage()));
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnackBar("Login Failed. Please check OTP.", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.red.shade800 : accentBrown,
    ));
  }

  // Consistent Input Decoration
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
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 100, bottom: 50),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person_pin, size: 80, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text("Farmer Login", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      Text("Access your individualized data", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Login Form Card
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text("Welcome Back", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 25),
                          
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            enabled: !_otpSent,
                            decoration: _buildInputDecoration("Registered Number", Icons.phone).copyWith(prefixText: "+91 "),
                          ),
                          
                          if (_otpSent) ...[
                            const SizedBox(height: 20),
                            TextField(
                              controller: _otp,
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration("6-Digit OTP", Icons.lock_outline),
                            ),
                          ],

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _otpSent ? _verifyOTPManual : _checkFarmerAndSendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text(
                                _otpSent ? "VERIFY & LOGIN" : "GET OTP",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("New Farmer? Register instead", style: TextStyle(color: accentBrown, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Data secured by Firebase Auth", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
    );
  }
}