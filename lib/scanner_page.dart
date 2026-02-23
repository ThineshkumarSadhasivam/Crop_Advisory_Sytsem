import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isScanCompleted = false;

void _linkDevice(String scannedCode) async {
  if (isScanCompleted) return;

  // --- NEW VALIDATION CHECK ---
  // If the QR contains a slash or is a URL, reject it
  if (scannedCode.contains('/') || scannedCode.contains('http')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invalid QR! Please scan the official IoT Kit QR code."),
        backgroundColor: Colors.red,
      ),
    );
    return; // Stop the process here
  }
  // ----------------------------

  setState(() => isScanCompleted = true);
  String uid = FirebaseAuth.instance.currentUser!.uid;

  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'iot_device_id': scannedCode,
    });

    if (!mounted) return;
    Navigator.pop(context); 
  } catch (e) {
    setState(() => isScanCompleted = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Error linking device.")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan IoT QR Code")),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            _linkDevice(barcodes.first.rawValue ?? "");
          }
        },
      ),
    );
  }
}