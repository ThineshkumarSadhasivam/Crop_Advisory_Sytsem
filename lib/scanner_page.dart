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
  MobileScannerController cameraController = MobileScannerController();

  // Logic: Fetch 10 Node IDs from a Group and link to Farmer
  void _linkFieldGroup(String scannedFieldID) async {
    if (isScanCompleted || scannedFieldID.isEmpty) return;

    // Validation: Ignore URLs
    if (scannedFieldID.contains('/') || scannedFieldID.contains('http')) {
      _showSnackBar("Invalid QR! Scan the Master Field ID code.", Colors.red);
      return;
    }

    setState(() => isScanCompleted = true);
    cameraController.stop(); // Stop camera to save battery and prevent double-scan

    String uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // 1. Fetch the document from 'field_groups' that contains the 10 sensor IDs
      DocumentSnapshot fieldGroupDoc = await FirebaseFirestore.instance
          .collection('field_groups')
          .doc(scannedFieldID)
          .get();

      if (fieldGroupDoc.exists) {
        // 2. Get the list of 10 IDs (e.g., KIT_01, KIT_02...)
        List<dynamic> nodeIds = fieldGroupDoc['nodes'] ?? [];

        // 3. Update the individual farmer's profile with all 10 IDs
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'iot_devices': nodeIds, // Overwrites empty list with the 10 real sensors
        });

        if (!mounted) return;
        _showSnackBar("Field Successfully Linked! 10 Zones detected.", Colors.green);

        // 4. Redirect to Dashboard
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (c) => const DashboardPage()), 
          (route) => false
        );
      } else {
        // Handle case where QR text doesn't exist in our 'field_groups' collection
        _showSnackBar("Field ID not found in database.", Colors.orange);
        setState(() => isScanCompleted = false);
        cameraController.start();
      }
    } catch (e) {
      setState(() => isScanCompleted = false);
      cameraController.start();
      _showSnackBar("Linking error. Check internet connection.", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Master Field QR"),
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
                _linkFieldGroup(barcodes.first.rawValue ?? "");
              }
            },
          ),
          // Visual Overlay
          Center(
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            bottom: 100, left: 0, right: 0,
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text("Scanning for Field Configuration...",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}