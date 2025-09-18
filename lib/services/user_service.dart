import 'dart:convert';
import '../models/user_info.dart';
import '../utils/preference_manager.dart';

class UserService {
  static UserService? _instance;

  static UserService get instance {
    _instance ??= UserService._internal();
    return _instance!;
  }

  UserService._internal();

  static const String _userInfoKey = 'user_info';
  static const String _isGuestKey = 'is_guest';

  Future<void> saveUserInfo(UserInfo userInfo) async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    await prefs.setString(_userInfoKey, jsonEncode(userInfo.toJson()));
  }

  Future<UserInfo?> getUserInfo() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    final userInfoJson = prefs.getString(_userInfoKey);
    if (userInfoJson != null) {
      try {
        final json = jsonDecode(userInfoJson) as Map<String, dynamic>;
        return UserInfo.fromJson(json);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    await prefs.setBool(_isGuestKey, isGuest);
  }

  Future<bool> isGuestMode() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    return prefs.getBool(_isGuestKey) ?? false;
  }

  Future<void> updateUserInfo(UserInfo userInfo) async {
    await saveUserInfo(userInfo);
  }

  Future<void> clearUserInfo() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    await prefs.remove(_userInfoKey);
    await prefs.remove(_isGuestKey);
  }

  Future<void> updateUserName(String name) async {
    final userInfo = await getUserInfo();
    if (userInfo != null) {
      final updatedUserInfo = userInfo.copyWith(name: name);
      await saveUserInfo(updatedUserInfo);
    }
  }
}
