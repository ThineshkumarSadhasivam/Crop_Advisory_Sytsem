import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scanner_page.dart';
import 'signup_page.dart'; // Fixed: added missing semicolon

class DashboardPage extends StatelessWidget {
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color accentGold = const Color(0xFFFBC02D);

  DashboardPage({super.key}); // Added constructor

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text("AgriSmart Dashboard"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 1. Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              // 2. Force navigation back to SignupPage and clear memory
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                  (route) => false,
                );
              }
            },
          ),
        ], // Comma here, not a semicolon
      ), // Comma here, not a semicolon
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          var userData = userSnapshot.data!;
          String deviceId = userData['iot_device_id'] ?? "";
          String soilType = userData['soil_type'] ?? "Unknown";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(userData['name'] ?? "Farmer", soilType),
                const SizedBox(height: 20),

                if (deviceId.isEmpty)
                  _buildNoDeviceCard(context)
                else
                  _buildLiveSensorSection(deviceId, soilType),
              ],
            ),
          );
        },
      ),
    );
  }

  // Header UI
  Widget _buildHeader(String name, String soil) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello, $name!", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text("Individualized Profile: $soil", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
      ],
    );
  }

  // Section 1: Fetching Real-time Sensor Data
  Widget _buildLiveSensorSection(String deviceId, String soilType) {
    // Validation
    if (deviceId.contains('/') || deviceId.isEmpty) {
      return const Center(child: Text("Invalid Device ID linked. Please re-scan."));
    }
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sensor_readings').doc(deviceId).snapshots(),
      builder: (context, sensorSnapshot) {
        if (!sensorSnapshot.hasData || !sensorSnapshot.data!.exists) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Waiting for IoT data... (Ensure your kit is ON)"),
          ));
        }

        var s = sensorSnapshot.data!;
        int n = s['n'] ?? 0;
        int p = s['p'] ?? 0;
        int k = s['k'] ?? 0;
        double moisture = (s['moisture'] ?? 0).toDouble();

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSensorGauge("Nitrogen", n, "mg/kg", Colors.blue),
                _buildSensorGauge("Phosphorus", p, "mg/kg", Colors.purple),
                _buildSensorGauge("Potassium", k, "mg/kg", Colors.orange),
              ],
            ),
            const SizedBox(height: 20),
            _buildMoistureCard(moisture),
            const SizedBox(height: 20),
            _buildAdvisoryCard(n, p, k, moisture, soilType),
            const SizedBox(height: 20),
            _buildMandiTrendCard(),
          ],
        );
      },
    );
  }

  Widget _buildSensorGauge(String label, int value, String unit, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: value / 100, color: color, backgroundColor: Colors.grey.shade100),
              Text("$value", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAdvisoryCard(int n, int p, int k, double moist, String soil) {
    String advice = "";
    String status = "Optimal";
    Color statusColor = Colors.green;

    if (n < 30) {
      advice = "Your Nitrogen is depleted for $soil. Avoid planting Corn now. Plant Legumes to naturally recover soil health.";
      status = "Action Required";
      statusColor = Colors.orange;
    } else if (moist < 20) {
      advice = "Soil moisture is low. Current weather forecast: No rain expected. Irrigate now.";
    } else {
      advice = "Soil chemistry is perfect for Rice/Maize. Market trends suggest price will rise 10% next month.";
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: statusColor, width: 6))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: primaryGreen),
                const SizedBox(width: 10),
                const Text("Individual Advisory", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const Divider(),
            Text(advice, style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 10),
            Chip(label: Text(status, style: const TextStyle(color: Colors.white)), backgroundColor: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMandiTrendCard() {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.trending_up, color: Colors.blue),
        title: const Text("Current Market Trend (Mandi)"),
        subtitle: const Text("Paddy: ₹2,300/quintal (↑ 5%)"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildMoistureCard(double val) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.water_drop, color: Colors.blue),
        title: const Text("Soil Moisture Content"),
        subtitle: LinearProgressIndicator(value: val / 100, backgroundColor: Colors.grey.shade200, color: Colors.blue),
        trailing: Text("${val.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            const Text("IoT Kit Not Linked", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Scan the QR code on your individual IoT kit to start receiving live soil advisory.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage())),
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text("LINK MY SENSOR KIT", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50)),
            )
          ],
        ),
      ),
    );
  }
}