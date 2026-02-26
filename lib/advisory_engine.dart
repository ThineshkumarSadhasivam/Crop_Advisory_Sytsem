import 'package:flutter/material.dart';

class AdvisoryEngine {
  static const Map<String, Map<String, dynamic>> cropBlueprints = {
    "Rice": {
      "n": 120,
      "p": 60,
      "k": 60,
      "water": 70,
      "incompatible": [],
      "conflict_msg": ""
    },
    "Groundnut": {
      "n": 25,
      "p": 50,
      "k": 75,
      "water": 30,
      "incompatible": ["Sugarcane", "Tobacco"],
      "conflict_msg":
          "Sugarcane pathogens (Sclerotium) stay in the soil and will rot Groundnut pods."
    },
    "Cotton": {
      "n": 80,
      "p": 40,
      "k": 40,
      "water": 40,
      "incompatible": ["Tomato"],
      "conflict_msg":
          "Tomato pests (Whiteflies) survive in soil and will attack Cotton seedlings."
    },
    "Sugarcane": {
      "n": 275,
      "p": 60,
      "k": 110,
      "water": 60,
      "incompatible": ["Groundnut"],
      "conflict_msg":
          "Groundnut soil pathogens can trigger root-wilt in new Sugarcane setts."
    },
    "Maize": {
      "n": 150,
      "p": 75,
      "k": 50,
      "water": 50,
      "incompatible": ["Sorghum"],
      "conflict_msg":
          "Soil fatigue: Maize and Sorghum compete for the exact same micronutrients."
    },
  };

  static Map<String, List<Map<String, dynamic>>> getCategorizedCrops({
    required int n,
    required int p,
    required int k,
    required List<dynamic> history,
  }) {
    List<Map<String, dynamic>> safeCrops = [];
    List<Map<String, dynamic>> riskyCrops = [];

    String lastHarvest = history.isNotEmpty ? history.last : "None";

    cropBlueprints.forEach((cropName, blueprint) {
      List<String> conflicts = List<String>.from(blueprint['incompatible']);

      // Calculate NPK Match Score
      double nMatch =
          (1 - ((blueprint['n'] - n).abs() / 200)).clamp(0.0, 1.0).toDouble();
      double pMatch =
          (1 - ((blueprint['p'] - p).abs() / 100)).clamp(0.0, 1.0).toDouble();
      double kMatch =
          (1 - ((blueprint['k'] - k).abs() / 150)).clamp(0.0, 1.0).toDouble();
      int score = ((nMatch + pMatch + kMatch) / 3 * 100).toInt();

      // --- LOGIC: SEPARATE INTO SAFE AND RISKY ---
      if (conflicts.contains(lastHarvest)) {
        riskyCrops.add({
          "crop": cropName,
          "reason": blueprint['conflict_msg'],
        });
      } else {
        safeCrops.add({
          "crop": cropName,
          "score": score,
          "reason": history.isEmpty
              ? "Safe for new soil."
              : "Safe rotation after $lastHarvest.",
        });
      }
    });

    safeCrops.sort((a, b) => b['score'].compareTo(a['score']));
    return {"safe": safeCrops, "risky": riskyCrops};
  }

  static Map<String, dynamic> getCurrentCropAdvice({
    required int n,
    required int p,
    required int k,
    required double moist,
    required String current,
    required List<dynamic> history,
  }) {
    if (current == "None")
      return {
        "status": "Field Empty",
        "color": Colors.blueGrey,
        "advice": "Select a match below to sow."
      };

    var blueprint = cropBlueprints[current];
    String lastHarvest = history.isNotEmpty ? history.last : "None";

    if (blueprint != null &&
        List<String>.from(blueprint['incompatible']).contains(lastHarvest)) {
      return {
        "status": "BIOLOGICAL RISK",
        "color": Colors.red,
        "advice": "⚠️ Alert: ${blueprint['conflict_msg']}"
      };
    }

    int nGap = (blueprint!['n'] - n);
    return {
      "status": "Active Management",
      "color": Colors.green,
      "advice": nGap > 0
          ? "Prescription: Add ${nGap}kg Urea."
          : "Soil chemistry is optimal."
    };
  }
}
