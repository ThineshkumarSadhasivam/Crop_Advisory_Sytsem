import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _landSizeController = TextEditingController();
  
  String _selectedSoilType = 'Black Soil'; 
  String? _verificationId; 
  bool _isOtpSent = false;
  bool _isLoading = false;

  // STEP 1: Send OTP to the mobile number
  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      _showSnackBar("Please enter a valid phone number");
      return;
    }

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      // Ensure the number has the country code (e.g., +91 for India)
      phoneNumber: '+91${_phoneController.text.trim()}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This only happens on some Android devices that auto-verify
        await _signInAndSaveData(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showSnackBar("Verification Failed: ${e.message}");
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
        _showSnackBar("OTP sent to +91${_phoneController.text}");
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // STEP 2: Verify OTP and Register the Farmer
  Future<void> _verifyAndRegister() async {
    if (_otpController.text.isEmpty) {
      _showSnackBar("Please enter the OTP");
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

  // STEP 3: Sign in and Save Individual Details to Firestore
  Future<void> _signInAndSaveData(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'phone': '+91${_phoneController.text.trim()}',
          'description': _descriptionController.text.trim(),
          'soil_type': _selectedSoilType,
          'land_size': _landSizeController.text.trim(),
          'iot_device_id': '', // Will be updated via QR scan
          'created_at': FieldValue.serverTimestamp(),
        });

        _showSnackBar("Farmer Profile Created Successfully!");
        // Navigate to Home/Dashboard here
      }
    } catch (e) {
      _showSnackBar("Error saving profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Farmer Registration")),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(controller: _nameController, decoration: InputDecoration(labelText: "Full Name", icon: Icon(Icons.person))),
                TextField(
                  controller: _phoneController, 
                  decoration: InputDecoration(labelText: "Mobile Number", prefixText: "+91 ", icon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  enabled: !_isOtpSent, // Disable phone input after OTP is sent
                ),
                
                if (_isOtpSent)
                  TextField(
                    controller: _otpController, 
                    decoration: InputDecoration(labelText: "6-Digit OTP", icon: Icon(Icons.lock_clock)),
                    keyboardType: TextInputType.number,
                  ),

                TextField(controller: _descriptionController, decoration: InputDecoration(labelText: "Land Description", icon: Icon(Icons.location_on))),
                TextField(controller: _landSizeController, decoration: InputDecoration(labelText: "Land Size (Acres)", icon: Icon(Icons.landscape)), keyboardType: TextInputType.number),
                
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _selectedSoilType,
                  decoration: InputDecoration(labelText: "Soil Type", icon: Icon(Icons.layers)),
                  onChanged: (newValue) => setState(() => _selectedSoilType = newValue!),
                  items: ['Black Soil', 'Red Soil', 'Sandy Soil', 'Clay Soil']
                      .map((soil) => DropdownMenuItem(value: soil, child: Text(soil))).toList(),
                ),
                
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isOtpSent ? _verifyAndRegister : _sendOTP,
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                  child: Text(_isOtpSent ? "Verify & Register" : "Send OTP"),
                ),
              ],
            ),
          ),
    );
  }
}