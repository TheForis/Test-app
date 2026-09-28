import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/brand.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs);

  static Future<SettingsController> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return SettingsController._(prefs);
  }

  final SharedPreferences? _prefs;

  ThemeMode get themeMode => ThemeMode.values[(_prefs?.getInt('themeMode') ?? 0).clamp(0, 2)];
  set themeMode(ThemeMode value) {
    _prefs?.setInt('themeMode', value.index);
    notifyListeners();
  }

  bool get showHidden => _prefs?.getBool('showHidden') ?? false;
  set showHidden(bool value) {
    _prefs?.setBool('showHidden', value);
    notifyListeners();
  }

  bool get gridView => _prefs?.getBool('gridView') ?? false;
  set gridView(bool value) {
    _prefs?.setBool('gridView', value);
    notifyListeners();
  }

  int get seedColor => _prefs?.getInt('seedColor') ?? Brand.ember.toARGB32();
  set seedColor(int value) {
    _prefs?.setInt('seedColor', value);
    notifyListeners();
  }
}
