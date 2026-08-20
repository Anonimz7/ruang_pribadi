import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global dark mode notifier — single source of truth
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

/// Load saved dark mode preference
Future<bool> loadDarkMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('darkMode') ?? false;
}

/// Persist dark mode preference
Future<void> saveDarkMode(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('darkMode', value);
}
