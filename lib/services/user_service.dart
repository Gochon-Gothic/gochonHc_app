import 'dart:convert';
import '../models/user_info.dart';
import '../utils/preference_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    print('UserService: Retrieved userInfoJson: $userInfoJson'); // Debug print
    if (userInfoJson != null) {
      try {
        final json = jsonDecode(userInfoJson) as Map<String, dynamic>;
        print('UserService: Decoded userInfoJson: $json'); // Debug print
        return UserInfo.fromJson(json);
      } catch (e) {
        print('UserService: Error decoding userInfoJson: $e'); // Debug print
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

  // Firebase에 사용자 정보 저장
  Future<void> saveUserToFirebase({
    required String uid,
    required String email,
    required String name,
    required int grade,
    required int classNum,
    required int number,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 사용자 정보를 Map으로 변환
      final userData = {
        'uid': uid,
        'email': email,
        'name': name,
        'grade': grade,
        'classNum': classNum,
        'number': number,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'hasSetup': true, // 이 함수가 호출되면 설정이 완료된 것임
      };

      // Firestore의 'users' 컬렉션에 문서 저장
      // 문서 ID는 uid를 사용 (고유성 보장)
      await firestore
          .collection('users')
          .doc(uid)
          .set(userData, SetOptions(merge: true)); // merge: true로 기존 데이터 보존
    } catch (e) {
      throw Exception('Firebase에 사용자 정보 저장 실패: $e');
    }
  }

  // Firestore에 사용자가 존재하는지 확인
  Future<bool> doesUserExist(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return snapshot.exists;
    } catch (e) {
      // 에러 발생 시 존재하지 않는 것으로 처리
      print('Error in doesUserExist for UID $uid: $e'); // Debug print
      return false;
    }
  }
}
