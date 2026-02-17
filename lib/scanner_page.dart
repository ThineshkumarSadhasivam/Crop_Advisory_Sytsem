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
    setState(() => isScanCompleted = true);

    String uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'iot_device_id': scannedCode,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Success: Linked to Device $scannedCode")),
      );
      Navigator.pop(context); // Go back to dashboard
    } catch (e) {
      setState(() => isScanCompleted = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error linking device")));
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