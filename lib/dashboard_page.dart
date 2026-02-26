import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scanner_page.dart';
import 'signup_page.dart';
import 'field_map_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  String? selectedSensorId;

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text("AgriSmart Advisor"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (c) => const SignupPage()),
                    (route) => false);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          // 1. Check if connection is active
          if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Get the document snapshot safely
          var snapshot = userSnapshot.data!;
          Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;

          // 3. SAFE ACCESS: Check if keys exist to prevent "Bad State" errors
          String croppingStyle = userData.containsKey('cropping_style') 
              ? userData['cropping_style'] 
              : "";

          List<dynamic> fieldGroups = userData.containsKey('iot_devices') 
              ? userData['iot_devices'] 
              : [];
              
          String soilType = userData.containsKey('soil_type') 
              ? userData['soil_type'] 
              : "Unknown";
          
          String farmerName = userData.containsKey('name') 
              ? userData['name'] 
              : "Farmer";

          // 4. Logic Gates for Navigation
          if (fieldGroups.isEmpty) {
            return _buildNoDeviceCard(context);
          }

          if (croppingStyle == "") {
            return _buildPreferenceSelection(uid, fieldGroups[0]);
          }

          // 5. FETCH THE LIST OF NODES FROM THE GROUP
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('field_groups')
                .doc(fieldGroups[0])
                .get(),
            builder: (context, groupSnapshot) {
              if (!groupSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (!groupSnapshot.data!.exists) return const Center(child: Text("Field Configuration Error."));

              List<dynamic> nodes = groupSnapshot.data!['nodes'] ?? [];
              selectedSensorId ??= nodes.isNotEmpty ? nodes[0] : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(farmerName, soilType, croppingStyle),
                    const SizedBox(height: 20),

                    const Text("ZONE MONITORING", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    _buildSensorDropdown(nodes, croppingStyle),
                    
                    const SizedBox(height: 25),

                    if (selectedSensorId != null)
                      _buildSelectedSensorDisplay(selectedSensorId!, soilType),

                    const SizedBox(height: 20),
                    _buildMandiTrendCard(),
                    
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () => FirebaseFirestore.instance.collection('users').doc(uid).update({'cropping_style': ""}),
                        child: const Text("Reset Field Preferences", style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- UI: Preference Selection ---
  Widget _buildPreferenceSelection(String uid, String fieldId) {
    return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('field_groups').doc(fieldId).get(),
        builder: (context, snapshot) {
          List<dynamic> nodes = snapshot.hasData ? (snapshot.data!['nodes'] ?? []) : [];
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_suggest, size: 80, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text("Field Setup", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Is this 2-acre field growing one crop or are you intercropping different zones?", textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  _prefButton(uid, "Single", "Whole Field (One Crop)", Icons.agriculture, nodes),
                  const SizedBox(height: 15),
                  _prefButton(uid, "Intercrop", "Intercropping (Zone Map)", Icons.grid_view, nodes),
                ],
              ),
            ),
          );
        });
  }

  Widget _prefButton(String uid, String val, String label, IconData icon, List<dynamic> nodes) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: Colors.white,
          foregroundColor: primaryGreen),
      onPressed: () {
        FirebaseFirestore.instance.collection('users').doc(uid).update({'cropping_style': val});
        if (val == "Intercrop") {
          Navigator.push(context, MaterialPageRoute(builder: (c) => FieldMapPage(nodes: nodes)));
        }
      },
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSensorDropdown(List<dynamic> nodes, String style) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryGreen)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSensorId,
                isExpanded: true,
                items: nodes.map((node) => DropdownMenuItem<String>(value: node, child: Text("Zone: $node"))).toList(),
                onChanged: (v) => setState(() => selectedSensorId = v),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () {
            if (style == "Intercrop") {
              Navigator.push(context, MaterialPageRoute(builder: (c) => FieldMapPage(nodes: nodes)));
            } else {
              _showSingleCropDialog(nodes);
            }
          },
          icon: Icon(style == "Intercrop" ? Icons.map : Icons.settings_suggest, color: primaryGreen, size: 35),
        )
      ],
    );
  }

  Widget _buildSelectedSensorDisplay(String sensorId, String soilType) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sensor_readings').doc(sensorId).snapshots(),
      builder: (context, sensorSnapshot) {
        if (!sensorSnapshot.hasData || !sensorSnapshot.data!.exists) {
          return const Center(child: Text("Zone Data Offline..."));
        }
        var s = sensorSnapshot.data!.data() as Map<String, dynamic>;
        int n = s['n'] ?? 0;
        int p = s['p'] ?? 0;
        int k = s['k'] ?? 0;
        double moisture = (s['moisture'] ?? 0).toDouble();

        return Column(
          children: [
            _buildNPKCard(n, p, k),
            const SizedBox(height: 20),
            _buildMoistureCard(moisture),
            const SizedBox(height: 20),
            _buildAdvisoryCard(n, moisture, soilType, sensorId, s),
          ],
        );
      },
    );
  }

  Widget _buildAdvisoryCard(int n, double moist, String soil, String id, Map<String, dynamic> data) {
    String current = data['current_crop'] ?? "None";
    String prev = data['previous_crop'] ?? "None";
    String advice = "";
    Color statusColor = Colors.green;
    IconData icon = Icons.verified;

    if (current == "Groundnut" && prev == "Sugarcane") {
      advice = "HIGH RISK: Sugarcane stubble detected. Microbial activity will damage Groundnut pods. Avoid for 4 months.";
      statusColor = Colors.red;
      icon = Icons.gpp_bad;
    } else if (current == "Rice" && n < 40) {
      advice = "Your Nitrogen is low ($n) for Rice. Apply 10kg Urea to this specific 200m zone.";
      statusColor = Colors.orange;
      icon = Icons.warning;
    } else if (current == "None") {
      advice = "Configure your crop using the settings icon to get advice.";
      statusColor = Colors.blueGrey;
      icon = Icons.info;
    } else {
      advice = "Soil chemistry is optimal for $current.";
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
            Row(children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: 10),
              const Text("Individualized Advisory", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
            ]),
            const Divider(),
            Text("Logic: $prev ➔ $current", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Text(advice, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
        ),
      ),
    );
  }

  void _showSingleCropDialog(List<dynamic> nodes) {
    String? cur;
    String? prev;
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Set Whole Field Crop"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Current Crop"),
                  items: ["Rice", "Cotton", "Sugarcane", "Groundnut"]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => cur = v,
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Previous Harvest"),
                  items: ["Rice", "Cotton", "Sugarcane", "Groundnut"]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => prev = v,
                ),
              ]),
              actions: [
                ElevatedButton(
                    onPressed: () async {
                      WriteBatch batch = FirebaseFirestore.instance.batch();
                      for (String id in nodes) {
                        batch.update(FirebaseFirestore.instance.collection('sensor_readings').doc(id),
                            {'current_crop': cur, 'previous_crop': prev});
                      }
                      await batch.commit();
                      Navigator.pop(context);
                    },
                    child: const Text("Apply to All Nodes"))
              ],
            ));
  }

  Widget _buildNPKCard(int n, int p, int k) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [_indicator("N", n, Colors.blue), _indicator("P", p, Colors.purple), _indicator("K", k, Colors.orange)]),
      ),
    );
  }

  Widget _indicator(String label, int val, Color color) {
    return Column(children: [
      CircularProgressIndicator(value: val / 100, color: color, strokeWidth: 6, backgroundColor: Colors.grey.shade100),
      const SizedBox(height: 8),
      Text("$label: $val", style: const TextStyle(fontWeight: FontWeight.bold))
    ]);
  }

  Widget _buildHeader(String name, String soil, String style) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Hello, $name!", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      Text("Profile: $soil | Plan: $style", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildMoistureCard(double val) {
    return Card(
        child: ListTile(
            leading: const Icon(Icons.water_drop, color: Colors.blue),
            title: const Text("Soil Moisture"),
            trailing: Text("${val.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold))));
  }

  Widget _buildMandiTrendCard() {
    return const Card(
        child: ListTile(
            leading: Icon(Icons.trending_up, color: Colors.blue),
            title: Text("Market Trend"),
            subtitle: Text("Paddy: ₹2,300/q (↑ 5%)")));
  }

  Widget _buildNoDeviceCard(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("No IoT Grid Detected", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ScannerPage())),
              child: const Text("LINK FIELD KIT")),
        ],
      ),
    );
  }
}