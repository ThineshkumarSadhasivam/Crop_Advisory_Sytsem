import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isScanCompleted = false;
  // Controller to manage the camera state
  MobileScannerController cameraController = MobileScannerController();

  void _linkDevice(String scannedCode) async {
    if (isScanCompleted || scannedCode.isEmpty) return;

    // Validation: No slashes or URLs
    if (scannedCode.contains('/') || scannedCode.contains('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid QR! Scan the official IoT Kit QR."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isScanCompleted = true);
    cameraController.stop(); // Stop camera immediately after a good scan

    String uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'iot_device_id': scannedCode,
      });

      if (!mounted) return;
      
      // SUCCESS: Go to Dashboard and clear the navigation stack
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (c) => DashboardPage()), 
        (route) => false
      );
    } catch (e) {
      setState(() => isScanCompleted = false);
      cameraController.start(); // Restart camera if DB update fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error linking device.")),
      );
    }
  }

  @override
  void dispose() {
    cameraController.dispose(); // Clean up resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Link Your Individual Kit"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _linkDevice(barcodes.first.rawValue ?? "");
              }
            },
          ),
          // Overlay to guide the farmer
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align QR Code inside the box",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}