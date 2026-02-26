import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneConfigPage extends StatefulWidget {
  final String userId;
  final String sensorId;
  final int zoneIndex;

  const ZoneConfigPage({super.key, required this.userId, required this.sensorId, required this.zoneIndex});

  @override
  State<ZoneConfigPage> createState() => _ZoneConfigPageState();
}

class _ZoneConfigPageState extends State<ZoneConfigPage> {
  String currentCrop = "None";
  String prevCrop = "None";
  final List<String> cropList = ["None", "Rice", "Cotton", "Sugarcane", "Groundnut", "Maize"];

  void _saveZoneConfig() async {
    // Update the specific sensor data in the farmer's profile
    // Logic: In a real app, we'd update the iot_nodes array. 
    // For now, let's store it directly in the sensor_readings document for that ID.
    await FirebaseFirestore.instance.collection('sensor_readings').doc(widget.sensorId).update({
      'current_crop': currentCrop,
      'previous_crop': prevCrop,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Configure Zone ${widget.zoneIndex}")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Setting up Node: ${widget.sensorId}", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: "What are you growing now?"),
              value: currentCrop,
              items: cropList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => currentCrop = val!),
            ),
            const SizedBox(height: 20),
            
            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: "What was the previous crop?"),
              value: prevCrop,
              items: cropList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => prevCrop = val!),
            ),
            
            const Spacer(),
            ElevatedButton(
              onPressed: _saveZoneConfig,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
              child: const Text("UPDATE ZONE LOGIC", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}