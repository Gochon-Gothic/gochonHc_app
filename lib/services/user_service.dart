import 'dart:convert';
import '../models/user_info.dart';
import '../utils/preference_manager.dart';

class UserService {
  static UserService? _instance;

  // 싱글톤 패턴
  static UserService get instance {
    _instance ??= UserService._internal();
    return _instance!;
  }

  UserService._internal();

  static const String _userInfoKey = 'user_info';
  static const String _isGuestKey = 'is_guest';

  // 사용자 정보 저장
  Future<void> saveUserInfo(UserInfo userInfo) async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    await prefs.setString(_userInfoKey, jsonEncode(userInfo.toJson()));
  }

  // 사용자 정보 불러오기
  Future<UserInfo?> getUserInfo() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    final userInfoJson = prefs.getString(_userInfoKey);
    if (userInfoJson != null) {
      try {
        final json = jsonDecode(userInfoJson) as Map<String, dynamic>;
        return UserInfo.fromJson(json);
      } catch (e) {
        // JSON 파싱 에러 시 null 반환
        return null;
      }
    }
    return null;
  }

  // 게스트 모드 설정
  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    await prefs.setBool(_isGuestKey, isGuest);
  }

  // 게스트 모드 확인
  Future<bool> isGuestMode() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    return prefs.getBool(_isGuestKey) ?? false;
  }

  // 사용자 정보 업데이트
  Future<void> updateUserInfo(UserInfo userInfo) async {
    await saveUserInfo(userInfo);
  }

  // 사용자 정보 삭제 (로그아웃 시)
  Future<void> clearUserInfo() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    await prefs.remove(_userInfoKey);
    await prefs.remove(_isGuestKey);
  }

  // 초기 설정 완료 여부 확인
  Future<bool> hasCompletedInitialSetup() async {
    final userInfo = await getUserInfo();
    return userInfo?.hasCompletedInitialSetup ?? false;
  }

  // 사용자 이름 업데이트
  Future<void> updateUserName(String name) async {
    final userInfo = await getUserInfo();
    if (userInfo != null) {
      final updatedUserInfo = userInfo.copyWith(name: name);
      await saveUserInfo(updatedUserInfo);
    }
  }

  // 선택과목 업데이트
  Future<void> updateSelectedSubjects(List<String> subjects) async {
    final userInfo = await getUserInfo();
    if (userInfo != null) {
      final updatedUserInfo = userInfo.copyWith(selectedSubjects: subjects);
      await saveUserInfo(updatedUserInfo);
    }
  }

  // 약관 동의 상태 업데이트
  Future<void> updateTermsAgreement(bool agreed) async {
    final userInfo = await getUserInfo();
    if (userInfo != null) {
      final updatedUserInfo = userInfo.copyWith(agreedToTerms: agreed);
      await saveUserInfo(updatedUserInfo);
    }
  }

  // 초기 설정 완료로 표시
  Future<void> markInitialSetupComplete() async {
    final userInfo = await getUserInfo();
    if (userInfo != null) {
      final updatedUserInfo = userInfo.copyWith(hasCompletedInitialSetup: true);
      await saveUserInfo(updatedUserInfo);
    }
  }
}
