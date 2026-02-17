import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scanner_page.dart'; // We will create this next

class DashboardPage extends StatelessWidget {
  final Color primaryGreen = const Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text("My Individual Farm"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!;
          String deviceId = userData['iot_device_id'] ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hello, ${userData['name']}!", 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Plot: North Field • Black Soil"),
                const SizedBox(height: 20),

                // Case 1: Device NOT Linked
                if (deviceId.isEmpty)
                  _buildNoDeviceCard(context)
                else
                  // Case 2: Device IS Linked (Show NPK Data)
                  _buildLiveDataDashboard(deviceId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoDeviceCard(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: primaryGreen),
            const SizedBox(height: 15),
            const Text("IoT Kit Not Linked", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Scan the QR code on your individual IoT kit to start receiving live soil advisory.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerPage())),
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text("LINK MY SENSOR KIT", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDataDashboard(String deviceId) {
    return Column(
      children: [
        const Text("LIVE SOIL DATA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        // We will create beautiful NPK gauges here in the next step!
        Text("Your Device ID: $deviceId", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 200, child: Center(child: Text("Live NPK Gauges will appear here..."))),
      ],
    );
  }
}