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

  // --- LOGIC: SOWING (Sync based on style) ---
  void _confirmSowing(String crop, List<dynamic> nodes, String style) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text("Sow $crop?"),
              content: Text(style == "Single"
                  ? "This will update the whole 2-acre field."
                  : "Only Zone $selectedSensorId will be updated."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () async {
                      WriteBatch batch = FirebaseFirestore.instance.batch();
                      List<dynamic> target =
                          style == "Single" ? nodes : [selectedSensorId];
                      for (String id in target) {
                        batch.update(
                            FirebaseFirestore.instance
                                .collection('sensor_readings')
                                .doc(id),
                            {'current_crop': crop});
                      }
                      await batch.commit();
                      Navigator.pop(context);
                      _showSnackBar("Sowing confirmed!", Colors.green);
                    },
                    child: const Text("Confirm"))
              ],
            ));
  }

  // --- LOGIC: HARVEST (Sync based on style) ---
  Future<void> _handleSmartHarvest(
      String crop, List<dynamic> nodes, String style) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    List<dynamic> target = style == "Single" ? nodes : [selectedSensorId];
    for (String id in target) {
      batch.update(
          FirebaseFirestore.instance.collection('sensor_readings').doc(id), {
        'history': FieldValue.arrayUnion([crop]),
        'current_crop': "None",
      });
    }
    await batch.commit();
    _showSnackBar("Harvest logged for ${target.length} zones.", Colors.orange);
  }

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
              onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> fieldGroups = userData['iot_devices'] ?? [];
          String style = userData['cropping_style'] ?? "";

          if (fieldGroups.isEmpty) return _buildNoDeviceCard(context);
          if (style == "")
            return _buildPreferenceSelection(uid, fieldGroups[0]);

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('field_groups')
                .doc(fieldGroups[0])
                .get(),
            builder: (context, groupSnapshot) {
              if (!groupSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              List<dynamic> nodes = groupSnapshot.data!['nodes'] ?? [];
              selectedSensorId ??= nodes[0]; // Default to first sensor

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sensor_readings')
                    .doc(selectedSensorId)
                    .snapshots(),
                builder: (context, sensorSnapshot) {
                  if (!sensorSnapshot.hasData || !sensorSnapshot.data!.exists)
                    return const Center(child: Text("Connecting to sensor..."));

                  var s = sensorSnapshot.data!.data() as Map<String, dynamic>;
                  int n = s['n'] ?? 0;
                  int p = s['p'] ?? 0;
                  int k = s['k'] ?? 0;
                  double moist = (s['moisture'] ?? 0).toDouble();
                  String curCrop = s['current_crop'] ?? "None";
                  List<dynamic> history = s['history'] ?? [];

                  var advice = AdvisoryEngine.getCurrentCropAdvice(
                      n: n,
                      p: p,
                      k: k,
                      moist: moist,
                      current: curCrop,
                      history: history);
                  var recommendations = AdvisoryEngine.getCategorizedCrops(
                      n: n, p: p, k: k, history: history);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(userData['name'], userData['soil_type']),
                        const SizedBox(height: 20),

                        // ZONE SELECTOR (Switch between individual sensors)
                        _buildZoneSelector(nodes),

                        const SizedBox(height: 20),

                        // --- THE UI YOU REQUESTED (LARGE GAUGES) ---
                        _buildNPKRow(n, p, k),
                        const SizedBox(height: 20),
                        _buildMoistureCard(moist),
                        const SizedBox(height: 25),

                        // SUGGESTIONS OR ADVISORY
                        if (curCrop == "None") ...[
                          const Text("RECOMMENDED CROPS",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          const SizedBox(height: 10),
                          _buildHorizontalList(
                              recommendations['safe']!, nodes, style, false),
                          const SizedBox(height: 15),
                          const Text("DO NOT SOW (BIOLOGICAL RISK)",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          const SizedBox(height: 10),
                          _buildHorizontalList(
                              recommendations['risky']!, nodes, style, true),
                        ] else ...[
                          _buildIndividualAdvisoryCard(
                              advice, curCrop, history, nodes, style),
                        ],

                        const SizedBox(height: 20),
                        _buildMandiTrendCard(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS MATCHING YOUR IMAGE ---

  Widget _buildHeader(String? name, String? soil) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Hello, ${name ?? 'Farmer'}!",
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      Text("Individualized Profile: $soil",
          style: const TextStyle(fontSize: 16, color: Colors.grey)),
    ]);
  }

  Widget _buildZoneSelector(List<dynamic> nodes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSensorId,
          isExpanded: true,
          items: nodes
              .map((n) => DropdownMenuItem<String>(
                  value: n,
                  child: Text("Viewing Zone: $n",
                      style: const TextStyle(fontWeight: FontWeight.bold))))
              .toList(),
          onChanged: (v) => setState(() => selectedSensorId = v),
        ),
      ),
    );
  }

  Widget _buildNPKRow(int n, int p, int k) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCircularGauge("Nitrogen", n, Colors.blue),
        _buildCircularGauge("Phosphorus", p, Colors.purple),
        _buildCircularGauge("Potassium", k, Colors.orange),
      ],
    );
  }

  Widget _buildCircularGauge(String label, int val, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Stack(alignment: Alignment.center, children: [
          SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                  value: val / 150,
                  color: color,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade100)),
          Text("$val",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        const Text("mg/kg", style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildMoistureCard(double val) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        const Icon(Icons.water_drop, color: Colors.blue, size: 30),
        const SizedBox(width: 15),
        const Expanded(
            child: Text("Soil Moisture Content",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        Text("${val.toInt()}%",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildIndividualAdvisoryCard(Map<String, dynamic> data, String cur,
      List<dynamic> history, List<dynamic> nodes, String style) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.settings_suggest, color: primaryGreen),
            const SizedBox(width: 10),
            const Text("Individual Advisory",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const Divider(),
          const SizedBox(height: 10),
          Text(data['advice'],
              style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: data['color'],
                minimumSize: const Size(150, 45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => _handleSmartHarvest(cur, nodes, style),
            child: Text(data['status'],
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }

  // --- LISTS, PREFS, AND SNACKBAR ---
  Widget _buildHorizontalList(List<Map<String, dynamic>> items,
      List<dynamic> nodes, String style, bool isRisky) {
    return SizedBox(
        height: 140,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              var item = items[index];
              return GestureDetector(
                onTap: isRisky
                    ? null
                    : () => _confirmSowing(item['crop'], nodes, style),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: isRisky ? Colors.red.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: isRisky ? Colors.red : Colors.green)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item['crop'],
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRisky ? Colors.red : Colors.black)),
                        if (!isRisky)
                          Text("${item['score']}% Match",
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        const Divider(),
                        Text(item['reason'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                color:
                                    isRisky ? Colors.redAccent : Colors.grey)),
                      ]),
                ),
              );
            }));
  }

  Widget _buildMandiTrendCard() {
    return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const ListTile(
            leading: Icon(Icons.trending_up, color: Colors.blue),
            title: Text("Current Market Trend (Mandi)"),
            subtitle: Text("Paddy: ₹2,300/quintal (↑ 5%)"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16)));
  }

  Widget _buildNoDeviceCard(BuildContext context) {
    return Center(
        child: ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (c) => const ScannerPage())),
            child: const Text("LINK FIELD KIT")));
  }

  Widget _buildPreferenceSelection(String uid, String fId) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.settings, size: 80, color: Colors.green),
      const Text("Setup Strategy"),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: () => FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'cropping_style': "Single"}),
          child: const Text("Whole Field (One Crop)")),
      ElevatedButton(
          onPressed: () => FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'cropping_style': "Intercrop"}),
          child: const Text("Intercropping (Zoned)"))
    ]));
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }
}
  