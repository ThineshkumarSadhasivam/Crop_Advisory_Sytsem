import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FieldMapPage extends StatefulWidget {
  final List<dynamic> nodes;
  const FieldMapPage({super.key, required this.nodes});

  @override
  State<FieldMapPage> createState() => _FieldMapPageState();
}

class _FieldMapPageState extends State<FieldMapPage> {
  final Set<String> _selectedNodes = {}; // Tracks selected zones
  final Color primaryGreen = const Color(0xFF2E7D32);

  // LOGIC: Batch update all selected sensors
  Future<void> _updateSelectedZones(String current, String prev) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (String id in _selectedNodes) {
      DocumentReference ref = FirebaseFirestore.instance.collection('sensor_readings').doc(id);
      batch.update(ref, {
        'current_crop': current,
        'previous_crop': prev,
      });
    }

    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Updated ${_selectedNodes.length} zones to $current")),
      );
      Navigator.pop(context);
    }
  }

  void _showAssignmentDialog() {
    String? tempCurrent;
    String? tempPrev;
    List<String> crops = ["None", "Rice", "Cotton", "Sugarcane", "Groundnut", "Maize"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Configure ${_selectedNodes.length} Selected Zones"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Current Crop"),
              items: crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => tempCurrent = val,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Previous Harvest"),
              items: crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => tempPrev = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () => _updateSelectedZones(tempCurrent ?? "None", tempPrev ?? "None"),
            child: const Text("Apply to Selected", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Field Zone Mapper"), backgroundColor: primaryGreen, foregroundColor: Colors.white),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Tap zones to group them (e.g. Zone 1-5 for Rice)", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: widget.nodes.length,
              itemBuilder: (context, index) {
                String id = widget.nodes[index];
                bool isSelected = _selectedNodes.contains(id);
                return InkWell(
                  onTap: () => setState(() => isSelected ? _selectedNodes.remove(id) : _selectedNodes.add(id)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: primaryGreen),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.layers, color: isSelected ? Colors.white : primaryGreen),
                        Text("Zone ${index + 1}", style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                        Text(id, style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedNodes.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _showAssignmentDialog,
            label: Text("Assign Crops (${_selectedNodes.length})"),
            icon: const Icon(Icons.edit),
            backgroundColor: primaryGreen,
          ) 
        : null,
    );
  }
}