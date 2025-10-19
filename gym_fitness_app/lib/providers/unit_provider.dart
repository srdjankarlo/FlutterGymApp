import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnitProvider extends ChangeNotifier {
  String _unit = 'Metric';
  String get unit => _unit;

  UnitProvider() {
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    final prefs = await SharedPreferences.getInstance();
    _unit = prefs.getString('preferred_unit') ?? 'Metric';
    notifyListeners();
  }

  Future<void> setUnit(String newUnit) async {
    if (newUnit == _unit) return;
    _unit = newUnit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_unit', newUnit);
    notifyListeners();
  }

  bool get isMetric => _unit == 'Metric';
  bool get isImperial => _unit == 'Imperial';
}
