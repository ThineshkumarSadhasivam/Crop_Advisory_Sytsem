import 'package:flutter/material.dart';

class AdvisoryEngine {
  // --- SCIENTIFIC RESEARCH DATABASE (TNAU / ICAR) ---
  static const Map<String, Map<String, dynamic>> cropBlueprints = {
    "Rice": {
      "n": 120, "p": 60, "k": 60, "water": 70, 
      "incompatible": [], 
      "reasons": {}
    },
    "Groundnut": {
      "n": 25, "p": 50, "k": 75, "water": 30, 
      "incompatible": ["Sugarcane", "Tobacco"],
      // SPECIFIC REASONS FOR CONFLICT
      "reasons": {
        "Sugarcane": "Sugarcane residue carries 'Sclerotium' fungi which causes Stem Rot in Groundnuts.",
        "Tobacco": "Tobacco Mosaic Virus persists in soil and will stunt Groundnut growth."
      }
    },
    "Cotton": {
      "n": 80, "p": 40, "k": 40, "water": 40, 
      "incompatible": ["Tomato"],
      "reasons": {
        "Tomato": "Both crops share 'Whitefly' pests; soil-borne larvae will attack young Cotton roots."
      }
    },
    "Sugarcane": {
      "n": 275, "p": 60, "k": 110, "water": 60, 
      "incompatible": ["Groundnut"],
      "reasons": {
        "Groundnut": "Groundnut pathogens can trigger root-wilt in newly planted Sugarcane setts."
      }
    },
    "Maize": {
      "n": 150, "p": 75, "k": 50, "water": 50, 
      "incompatible": ["Sorghum"],
      "reasons": {
        "Sorghum": "Sorghum roots release hydrocyanic acid which inhibits Maize germination."
      }
    },
  };

  // --- LAYER 1: RANKED SUGGESTIONS ---
  static List<Map<String, dynamic>> suggestRankedCrops({
    required int n, required int p, required int k, required List<dynamic> history,
  }) {
    List<Map<String, dynamic>> rankedList = [];
    String lastHarvest = history.isNotEmpty ? history.last : "None";

    cropBlueprints.forEach((cropName, blueprint) {
      List<String> conflicts = List<String>.from(blueprint['incompatible']);
      if (conflicts.contains(lastHarvest)) return; 

      double nMatch = (1 - ((blueprint['n'] - n).abs() / 200)).clamp(0.0, 1.0).toDouble();
      double pMatch = (1 - ((blueprint['p'] - p).abs() / 100)).clamp(0.0, 1.0).toDouble();
      double kMatch = (1 - ((blueprint['k'] - k).abs() / 150)).clamp(0.0, 1.0).toDouble();
      
      int totalScore = ((nMatch + pMatch + kMatch) / 3 * 100).toInt();

      String reason = history.isEmpty ? "Safe for new soil." : "Safe rotation after $lastHarvest.";
      if (n < 30 && cropName == "Groundnut") reason = "Restores Nitrogen.";

      rankedList.add({
        "crop": cropName,
        "score": totalScore,
        "reason": reason,
        "n_gap": (blueprint['n'] - n).toInt(),
      });
    });

    rankedList.sort((a, b) => b['score'].compareTo(a['score']));
    return rankedList;
  }

  // --- LAYER 2: MANAGEMENT (WITH SPECIFIC CONFLICT MESSAGES) ---
  static Map<String, dynamic> getCurrentCropAdvice({
    required int n, required int p, required int k,
    required double moist, required String current, required List<dynamic> history,
  }) {
    if (current == "None") return {"status": "Field Ready", "color": Colors.blueGrey, "advice": "Select a suggested crop below to begin."};

    var blueprint = cropBlueprints[current];
    if (blueprint == null) return {"status": "Error", "color": Colors.grey, "advice": "Invalid Crop."};

    String lastHarvest = history.isNotEmpty ? history.last : "None";

    // --- ENHANCED SPECIFIC CONFLICT LOGIC ---
    List<String> conflicts = List<String>.from(blueprint['incompatible']);
    if (conflicts.contains(lastHarvest)) {
      // Fetch the specific scientific reason from the map
      String specificReason = blueprint['reasons'][lastHarvest] ?? "Biologically incompatible with $lastHarvest.";
      
      return {
        "status": "BIOLOGICAL RISK", 
        "color": Colors.red,
        "advice": "⚠️ Alert: $specificReason We recommend waiting 4 months."
      };
    }

    int nGap = (blueprint['n'] - n);
    String prescription = nGap > 0 ? "Apply ${nGap}kg Urea." : "Soil nutrients optimal.";
    
    return {
      "status": "Healthy Growth", "color": Colors.green,
      "advice": prescription
    };
  }
}