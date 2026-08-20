import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/arithmetic_operation.dart';

class SettingsProvider extends ChangeNotifier {
  ArithmeticOperation selectedOperation = ArithmeticOperation.addition;
  int questionsPerSession = 10;
  int questionTime = 5;
  String keyboardSize = "medium";

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    questionsPerSession = prefs.getInt('questionsPerSession') ?? 10;
    questionTime = prefs.getInt('questionTime') ?? 5;
    keyboardSize = prefs.getString('keyboardSize') ?? "medium";
    int opIndex = prefs.getInt('selectedOperation') ?? 0;
    selectedOperation = ArithmeticOperation.values[opIndex];
    notifyListeners();
  }

  Future<void> saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('questionsPerSession', questionsPerSession);
    await prefs.setInt('questionTime', questionTime);
    await prefs.setString('keyboardSize', keyboardSize);
    await prefs.setInt('selectedOperation', selectedOperation.index);
  }

  void updateQuestionsPerSession(int value) {
    questionsPerSession = value;
    saveSettings();
    notifyListeners();
  }

  void updateQuestionTime(int value) {
    questionTime = value;
    saveSettings();
    notifyListeners();
  }

  void updateKeyboardSize(String size) {
    keyboardSize = size;
    saveSettings();
    notifyListeners();
  }

  void updateSelectedOperation(ArithmeticOperation op) {
    selectedOperation = op;
    saveSettings();
    notifyListeners();
  }
}
