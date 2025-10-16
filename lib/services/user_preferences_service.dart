import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Kullanıcı tercihlerini yöneten servis
class UserPreferencesService {
  static const String _keyLeftPanelCollapsed = 'left_panel_collapsed';
  static const String _keyLeftPanelPinned = 'left_panel_pinned';
  static const String _keyLeftPanelPositionX = 'left_panel_position_x';
  static const String _keyLeftPanelPositionY = 'left_panel_position_y';
  static const String _keyLeftPanelWidth = 'left_panel_width';
  static const String _keyLeftPanelHeight = 'left_panel_height';
  static const String _keyToolMenuVisible = 'tool_menu_visible';

  static UserPreferencesService? _instance;
  SharedPreferences? _prefs;

  UserPreferencesService._();

  /// Singleton instance
  static Future<UserPreferencesService> getInstance() async {
    if (_instance == null) {
      _instance = UserPreferencesService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============== LEFT PANEL PREFERENCES ==============

  /// Sol panel küçültülmüş mü?
  bool get isLeftPanelCollapsed =>
      _prefs?.getBool(_keyLeftPanelCollapsed) ?? false;

  Future<void> setLeftPanelCollapsed(bool value) async {
    await _prefs?.setBool(_keyLeftPanelCollapsed, value);
  }

  /// Sol panel sabitlenmiş mi?
  bool get isLeftPanelPinned =>
      _prefs?.getBool(_keyLeftPanelPinned) ?? false;

  Future<void> setLeftPanelPinned(bool value) async {
    await _prefs?.setBool(_keyLeftPanelPinned, value);
  }

  /// Sol panel pozisyonu
  Offset get leftPanelPosition {
    final x = _prefs?.getDouble(_keyLeftPanelPositionX) ?? 20.0;
    final y = _prefs?.getDouble(_keyLeftPanelPositionY) ?? 100.0;
    return Offset(x, y);
  }

  Future<void> setLeftPanelPosition(Offset position) async {
    await _prefs?.setDouble(_keyLeftPanelPositionX, position.dx);
    await _prefs?.setDouble(_keyLeftPanelPositionY, position.dy);
  }

  /// Sol panel genişliği
  double get leftPanelWidth =>
      _prefs?.getDouble(_keyLeftPanelWidth) ?? 200.0;

  Future<void> setLeftPanelWidth(double value) async {
    await _prefs?.setDouble(_keyLeftPanelWidth, value);
  }

  /// Sol panel yüksekliği
  double get leftPanelHeight =>
      _prefs?.getDouble(_keyLeftPanelHeight) ?? 600.0;

  Future<void> setLeftPanelHeight(double value) async {
    await _prefs?.setDouble(_keyLeftPanelHeight, value);
  }

  // ============== TOOL MENU PREFERENCES ==============

  /// Araç menüsü görünür mü?
  bool get isToolMenuVisible =>
      _prefs?.getBool(_keyToolMenuVisible) ?? false;

  Future<void> setToolMenuVisible(bool value) async {
    await _prefs?.setBool(_keyToolMenuVisible, value);
  }

  // ============== CLEAR ALL ==============

  /// Tüm tercihleri temizle
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  /// Belirli tercihleri temizle
  Future<void> clearLeftPanelPreferences() async {
    await _prefs?.remove(_keyLeftPanelCollapsed);
    await _prefs?.remove(_keyLeftPanelPinned);
    await _prefs?.remove(_keyLeftPanelPositionX);
    await _prefs?.remove(_keyLeftPanelPositionY);
    await _prefs?.remove(_keyLeftPanelWidth);
    await _prefs?.remove(_keyLeftPanelHeight);
  }
}
