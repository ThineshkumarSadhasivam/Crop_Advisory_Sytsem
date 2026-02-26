import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'advisory_engine.dart';
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

  // --- LOGIC: SMART SOWING (Batch update for Single Plan) ---
  void _confirmSowing(String cropName, List<dynamic> allNodes, String style) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Sow $cropName?"),
        content: Text(style == "Single" 
          ? "This will apply $cropName to your ENTIRE field ledger." 
          : "Apply ONLY to Zone $selectedSensorId."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () async {
              WriteBatch batch = FirebaseFirestore.instance.batch();
              // Determine targets: All IDs if Single, only selected if Intercrop
              List<dynamic> targets = (style == "Single") ? allNodes : [selectedSensorId];
              
              for (String id in targets) {
                batch.update(FirebaseFirestore.instance.collection('sensor_readings').doc(id), 
                {'current_crop': cropName});
              }
              await batch.commit();
              if (mounted) Navigator.pop(context);
              _showSnackBar("Sowing started for ${targets.length} zone(s).", Colors.green);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- LOGIC: SMART HARVEST (Batch update for Single Plan) ---
  Future<void> _handleSmartHarvest(String cropName, List<dynamic> allNodes, String style) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    // Determine targets: All IDs if Single, only selected if Intercrop
    List<dynamic> targets = (style == "Single") ? allNodes : [selectedSensorId];

    for (String id in targets) {
      batch.update(FirebaseFirestore.instance.collection('sensor_readings').doc(id), {
        'history': FieldValue.arrayUnion([cropName]), // Add to ALL ledgers
        'current_crop': "None", // Reset ALL zones
      });
    }
    await batch.commit();
    _showSnackBar("Harvest logged for ${targets.length} zone(s).", Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text("AgriSmart Advisor"),
        backgroundColor: primaryGreen, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const SignupPage()), (r) => false);
          })
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData || userSnapshot.data?.data() == null) return const Center(child: CircularProgressIndicator());
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          
          List<dynamic> fieldGroups = userData['iot_devices'] ?? [];
          String style = userData['cropping_style'] ?? "";

          if (fieldGroups.isEmpty) return _buildNoDeviceCard(context);
          if (style == "") return _buildPreferenceSelection(uid, fieldGroups[0]);

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('field_groups').doc(fieldGroups[0]).get(),
            builder: (context, groupSnapshot) {
              if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) return const Center(child: CircularProgressIndicator());
              List<dynamic> nodes = groupSnapshot.data!['nodes'] ?? [];
              selectedSensorId ??= nodes.isNotEmpty ? nodes[0] : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(userData['name'], userData['soil_type'], style),
                    const SizedBox(height: 20),
                    _buildSensorDropdown(nodes, style),
                    const SizedBox(height: 25),
                    if (selectedSensorId != null)
                      _buildSelectedSensorDisplay(selectedSensorId!, nodes, style),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: () => FirebaseFirestore.instance.collection('users').doc(uid).update({'cropping_style': ""}), child: const Text("Reset Field Strategy", style: TextStyle(color: Colors.grey)))),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedSensorDisplay(String sensorId, List<dynamic> allNodes, String style) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sensor_readings').doc(sensorId).snapshots(),
      builder: (context, sensorSnapshot) {
        if (!sensorSnapshot.hasData || !sensorSnapshot.data!.exists) return const Center(child: Text("Connecting..."));
        
        var s = sensorSnapshot.data!.data() as Map<String, dynamic>;
        int n = s['n'] ?? 0; int p = s['p'] ?? 0; int k = s['k'] ?? 0;
        double moist = (s['moisture'] ?? 0).toDouble();
        String current = s['current_crop'] ?? "None";
        List<dynamic> history = s['history'] ?? []; 

        var advice = AdvisoryEngine.getCurrentCropAdvice(n: n, p: p, k: k, moist: moist, current: current, history: history);
        var rankedSuggestions = AdvisoryEngine.suggestRankedCrops(n: n, p: p, k: k, history: history);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNPKCard(n, p, k),
            const SizedBox(height: 25),
            _buildHistoryTimeline(history),
            const SizedBox(height: 25),

            // SOWING SUGGESTIONS (Only visible when field is empty)
            if (current == "None") ...[
              const Text("TAP A CROP TO START SOWING", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
              const SizedBox(height: 12),
              _buildInteractiveSuggestionList(rankedSuggestions, allNodes, style),
              const SizedBox(height: 25),
            ],

            _buildAdvisoryCard(advice, current, history, allNodes, style),
            const SizedBox(height: 20),
            _buildMandiTrendCard(),
          ],
        );
      },
    );
  }

  // --- UI: TAP TO SOW LIST ---
  Widget _buildInteractiveSuggestionList(List<Map<String, dynamic>> items, List<dynamic> nodes, String style) {
    return SizedBox(height: 130, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length, itemBuilder: (context, index) {
      var item = items[index]; bool isIdeal = index == 0;
      return GestureDetector(
        onTap: () => _confirmSowing(item['crop'], nodes, style),
        child: Container(width: 145, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isIdeal ? Colors.green.shade50 : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isIdeal ? Colors.green : Colors.grey.shade300, width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item['crop'], style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("${item['score']}% Fit", style: TextStyle(color: isIdeal ? Colors.green : Colors.blue, fontWeight: FontWeight.bold)),
            const Divider(),
            const Text("TAP TO SOW", style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
    }));
  }

  // --- UI: THE ADVISORY CARD (With Smart Harvest) ---
  Widget _buildAdvisoryCard(Map<String, dynamic> data, String cur, List<dynamic> history, List<dynamic> nodes, String style) {
    String last = history.isNotEmpty ? history.last : "Virgin Soil";
    return Card(
      elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border(left: BorderSide(color: data['color'] ?? Colors.grey, width: 6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['status'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: data['color'])),
          Text("History: $last ➔ Current: $cur", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Divider(),
          Text(data['advice'] ?? "", style: const TextStyle(fontSize: 15, height: 1.4)),
          if (cur != "None") ...[
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () => _handleSmartHarvest(cur, nodes, style), 
              icon: const Icon(Icons.grass), 
              label: Text(style == "Single" ? "HARVEST ENTIRE FIELD" : "HARVEST THIS ZONE"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            )
          ]
        ]),
      ),
    );
  }

  // --- UI: VISUAL HISTORY TIMELINE ---
  Widget _buildHistoryTimeline(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("FIELD LEDGER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 14)),
      const SizedBox(height: 10),
      SizedBox(height: 50, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: history.length, itemBuilder: (context, index) {
        bool isLast = index == history.length - 1;
        return Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryGreen, width: 1.5)),
            child: Text(history[index], style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 12))),
          if (!isLast) const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
        ]);
      })),
    ]);
  }

  // Helper UI Widgets
  Widget _buildNPKCard(int n, int p, int k) { return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_indicator("N", n, Colors.blue), _indicator("P", p, Colors.purple), _indicator("K", k, Colors.orange)]))); }
  Widget _indicator(String label, int val, Color color) { return Column(children: [CircularProgressIndicator(value: val / 150, color: color, strokeWidth: 5, backgroundColor: Colors.grey.shade100), const SizedBox(height: 8), Text("$label: $val", style: const TextStyle(fontWeight: FontWeight.bold))]); }
  Widget _buildHeader(String? name, String? soil, String style) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Hello, ${name ?? 'Farmer'}!", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text("Soil: $soil | Plan: $style", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]); }
  Widget _buildMoistureCard(double val) { return Card(child: ListTile(leading: const Icon(Icons.water_drop, color: Colors.blue), title: const Text("Moisture"), trailing: Text("${val.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)))); }
  Widget _buildMandiTrendCard() { return const Card(child: ListTile(leading: Icon(Icons.trending_up, color: Colors.blue), title: Text("Mandi Price Forecast"), subtitle: Text("Price predicted to rise 12% at harvest time."))); }
  Widget _buildSensorDropdown(List<dynamic> nodes, String style) { return Row(children: [Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryGreen)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: selectedSensorId, isExpanded: true, items: nodes.map((n) => DropdownMenuItem<String>(value: n, child: Text("Zone ID: $n"))).toList(), onChanged: (v) => setState(() => selectedSensorId = v))))), if (style == "Intercrop") ...[const SizedBox(width: 10), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => FieldMapPage(nodes: nodes))), icon: const Icon(Icons.map, color: Colors.green, size: 30))]]); }
  Widget _buildPreferenceSelection(String uid, String fId) { return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('field_groups').doc(fId).get(), builder: (context, snapshot) { List<dynamic> nodes = snapshot.hasData ? (snapshot.data!['nodes'] ?? []) : []; return Center(child: Padding(padding: const EdgeInsets.all(25), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.settings_suggest, size: 80, color: Colors.green), const Text("Field Setup", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20), const Text("How are you cultivating this field?", textAlign: TextAlign.center), const SizedBox(height: 40), _prefButton(uid, "Single", "Whole Field (One Crop)", Icons.agriculture, nodes), const SizedBox(height: 15), _prefButton(uid, "Intercrop", "Intercropping (Zone Map)", Icons.grid_view, nodes)]))); }); }
  Widget _prefButton(String uid, String val, String label, IconData icon, List<dynamic> nodes) { return ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)), onPressed: () { FirebaseFirestore.instance.collection('users').doc(uid).update({'cropping_style': val}); if (val == "Intercrop") Navigator.push(context, MaterialPageRoute(builder: (c) => FieldMapPage(nodes: nodes))); }, icon: Icon(icon), label: Text(label)); }
  Widget _buildNoDeviceCard(BuildContext context) { return Center(child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ScannerPage())), child: const Text("LINK FIELD KIT"))); }
  void _showSnackBar(String msg, Color color) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)); }
}