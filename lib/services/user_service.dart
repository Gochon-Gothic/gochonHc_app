import 'dart:async';
import 'dart:convert';
import '../models/user_info.dart';
import '../utils/preference_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 정보 로컬·Firestore 관리 (싱글톤)
///
/// [로직 흐름]
/// 1. saveUserInfo/getUserInfo: SharedPreferences user_info 키에 JSON 저장/조회
///    - getUserInfo: grade, classNum, number, nickname 중 하나라도 없으면 clearUserInfo 후 null
/// 2. saveUserToFirebase: Firestore users/{uid}에 merge: true로 저장
/// 3. setElectiveSetupSkipped: electiveSubjects={}, hasElectiveSetup=true로 설정
/// 4. saveElectiveSubjects: electiveSubjects, hasElectiveSetup 업데이트
/// 5. getElectiveSubjects, hasElectiveSetup: Firestore에서 조회
class UserService {
  static UserService? _instance;

  static UserService get instance {
    _instance ??= UserService._internal();
    return _instance!;
  }

  UserService._internal();

  static const String _userInfoKey = 'user_info';
  static const String _isGuestKey = 'is_guest';

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> saveUserInfo(UserInfo userInfo) async {
    try {
      final prefs = await PreferenceManager.instance.getSharedPreferences();
      await prefs.setString(_userInfoKey, jsonEncode(userInfo.toJson()));
    } catch (_) {}
  }

  Future<UserInfo?> getUserInfo() async {
    final prefs = await PreferenceManager.instance.getSharedPreferences();
    final userInfoJson = prefs.getString(_userInfoKey);
    if (userInfoJson != null) {
      try {
        final json = jsonDecode(userInfoJson) as Map<String, dynamic>;
        final nickname =
            (json['nickname'] as String?) ?? (json['name'] as String?) ?? '';
        final grade = _readInt(json['grade']);
        final classNum = _readInt(json['classNum']);
        final number = _readInt(json['number']);
        
        // 필수 필드가 모두 있고 nickname이 비어있지 않아야 함
        if (grade == null || classNum == null || number == null || nickname.isEmpty) {
          await clearUserInfo();
          return null;
        }
        
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

  Future<void> updateUserNickname(String nickname) async {
    final userInfo = await getUserInfo();
    if (userInfo != null) {
      final updatedUserInfo = userInfo.copyWith(nickname: nickname);
      await saveUserInfo(updatedUserInfo);
    }
  }

  Future<bool> _isFirstSetup(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return !doc.exists;
  }

  // Firebase에 사용자 정보 저장
  Future<void> saveUserToFirebase({
    required String uid,
    required String email,
    required String nickname,
    required int grade,
    required int classNum,
    required int number,
    bool? hasElectiveSetup,
  }) async {
    const retryDelays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 0; attempt < retryDelays.length; attempt++) {
      try {
        final firestore = FirebaseFirestore.instance;
        final isFirstSetup = await _isFirstSetup(uid);

        final userData = <String, dynamic>{
          'uid': uid,
          'email': email,
          'nickname': nickname,
          'name': FieldValue.delete(),
          'grade': grade,
          'classNum': classNum,
          'number': number,
          'updatedAt': FieldValue.serverTimestamp(),
          'hasSetup': true,
        };

        if (hasElectiveSetup != null) {
          userData['hasElectiveSetup'] = hasElectiveSetup;
        }

        if (isFirstSetup) {
          userData['createdAt'] = FieldValue.serverTimestamp();
        }

        await firestore
            .collection('users')
            .doc(uid)
            .set(userData, SetOptions(merge: true));
        return;
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;

        if (attempt == retryDelays.length - 1) {
          break;
        }

        await Future.delayed(retryDelays[attempt]);
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
  }

  // Firestore에 사용자가 존재하는지 확인
  Future<bool> doesUserExist(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return snapshot.exists;
    } catch (e) {
      // 에러 발생 시 존재하지 않는 것으로 처리
      return false;
    }
  }

  /// 선택과목 정보 없이 메인으로 스킵할 때 호출 (hasElectiveSetup=true로 설정)
  Future<void> setElectiveSetupSkipped(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'electiveSubjects': <String, String>{},
        'updatedAt': FieldValue.serverTimestamp(),
        'hasElectiveSetup': true,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // 선택과목 정보를 Firestore에 저장
  Future<void> saveElectiveSubjects(String uid, Map<String, String> electiveSubjects) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'electiveSubjects': electiveSubjects,
        'updatedAt': FieldValue.serverTimestamp(),
        'hasElectiveSetup': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('선택과목 저장 실패: $e');
    }
  }

  // 선택과목 정보를 Firestore에서 가져오기
  Future<Map<String, String>?> getElectiveSubjects(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final electiveSubjects = data['electiveSubjects'];
        if (electiveSubjects is Map) {
          return electiveSubjects.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 선택과목 설정이 완료되었는지 확인
  Future<bool> hasElectiveSetup(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        return doc.data()!['hasElectiveSetup'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
