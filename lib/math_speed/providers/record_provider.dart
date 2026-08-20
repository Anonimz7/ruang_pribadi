import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/arithmetic_operation.dart';
import '../models/record.dart';

class RecordProvider extends ChangeNotifier {
  Map<ArithmeticOperation, Record> records = {};

  RecordProvider() {
    loadRecords();
  }

  Future<void> loadRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var op in ArithmeticOperation.values) {
      String opKey = _opToKey(op);
      int score = prefs.getInt('record_${opKey}_score') ?? 0;
      double time = prefs.getDouble('record_${opKey}_time') ?? double.infinity;
      records[op] = Record(topScore: score, bestAverageTime: time);
    }
    notifyListeners();
  }

  Future<bool> updateRecord(
      ArithmeticOperation op, int newScore, double newAvgTime) async {
    Record? current = records[op];
    bool isUpdated = false;
    if (current == null ||
        newScore > current.topScore ||
        (newScore == current.topScore &&
            newAvgTime < current.bestAverageTime)) {
      records[op] = Record(topScore: newScore, bestAverageTime: newAvgTime);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String opKey = _opToKey(op);
      await prefs.setInt('record_${opKey}_score', newScore);
      await prefs.setDouble('record_${opKey}_time', newAvgTime);
      isUpdated = true;
      notifyListeners();
    }
    return isUpdated;
  }

  String _opToKey(ArithmeticOperation op) {
    switch (op) {
      case ArithmeticOperation.addition:
        return "addition";
      case ArithmeticOperation.subtraction:
        return "subtraction";
      case ArithmeticOperation.multiplication:
        return "multiplication";
      case ArithmeticOperation.division:
        return "division";
    }
  }
}
