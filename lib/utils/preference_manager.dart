import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 기반 로컬 저장소 관리 (싱글톤)
///
/// [로직 흐름]
/// 1. initialize(): SharedPreferences 인스턴스 획득 (최초 1회)
/// 2. 각 키별 get/set 메서드:
///    - user_email: 로그인 이메일
///    - theme_mode: 테마 (라이트/다크)
///    - timetable_cache: 시간표 API 캐시 (1시간 유효)
///    - meal_cache: 급식 캐시 (3일 유효, lunch_screen에서 별도 관리)
///    - favorite_stations: 즐겨찾기 버스 정류장 (stationId:::name:::num:::district 형식, ||| 구분)
///    - show_elective_unavailable: 선택과목 미사용 모달 표시 여부
///    - schedule_cache: 학사일정 캐시 (3/2, 9/1에는 무조건 null 반환 → API 재요청)
///    - grade_refresh_year: 학년반 갱신 완료 연도 (3/2 이후 needsGradeRefreshThisYear 판단)
/// 3. clearCache(): 모든 캐시 키 삭제
class PreferenceManager {
  static PreferenceManager? _instance;
  static SharedPreferences? _prefs;

  static PreferenceManager get instance {
    _instance ??= PreferenceManager._internal();
    return _instance!;
  }

  PreferenceManager._internal();

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static const String _userEmailKey = 'user_email';

  Future<String?> getUserEmail() async {
    await initialize();
    return _prefs!.getString(_userEmailKey);
  }

  Future<void> setUserEmail(String email) async {
    await initialize();
    await _prefs!.setString(_userEmailKey, email);
  }

  Future<void> removeUserEmail() async {
    await initialize();
    await _prefs!.remove(_userEmailKey);
  }

  static const String _themeKey = 'theme_mode';

  Future<bool> getThemeMode() async {
    await initialize();
    return _prefs!.getBool(_themeKey) ?? false;
  }

  Future<void> setThemeMode(bool isDark) async {
    await initialize();
    await _prefs!.setBool(_themeKey, isDark);
  }

  static const String _timetableCacheKey = 'timetable_cache';
  static const String _timetableCacheTimeKey = 'timetable_cache_time';

  /// 시간표 캐시: 1시간(3600000ms) 이내면 반환, 아니면 null
  Future<Map<String, dynamic>?> getTimetableCache() async {
    await initialize();
    final cacheTime = _prefs!.getInt(_timetableCacheTimeKey);
    if (cacheTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTime < 3600000) {
        final cacheData = _prefs!.getString(_timetableCacheKey);
        if (cacheData != null) {
          try {
            return Map<String, dynamic>.from(jsonDecode(cacheData) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  Future<void> setTimetableCache(Map<String, dynamic> data) async {
    await initialize();
    await _prefs!.setString(_timetableCacheKey, jsonEncode(data));
    await _prefs!.setInt(
      _timetableCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static const String _mealCacheKey = 'meal_cache';
  static const String _mealCacheTimeKey = 'meal_cache_time';

  /// 급식 캐시: 3일(259200000ms) 이내면 반환
  Future<Map<String, dynamic>?> getMealCache() async {
    await initialize();
    final cacheTime = _prefs!.getInt(_mealCacheTimeKey);
    if (cacheTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTime < 259200000) {
        final cacheData = _prefs!.getString(_mealCacheKey);
        if (cacheData != null) {
          try {
            return Map<String, dynamic>.from(jsonDecode(cacheData) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  Future<void> setMealCache(Map<String, dynamic> data) async {
    await initialize();
    await _prefs!.setString(_mealCacheKey, jsonEncode(data));
    await _prefs!.setInt(
      _mealCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static const String _favoriteStationsKey = 'favorite_stations';

  /// 즐겨찾기 정류장: "id:::name:::num:::district|||..." 형식으로 저장
  Future<List<Map<String, dynamic>>> getFavoriteStations() async {
    await initialize();
    final String? favoriteStationsJson = _prefs!.getString(_favoriteStationsKey);
    if (favoriteStationsJson == null || favoriteStationsJson.isEmpty) {
      return [];
    }
    try {
      final List<Map<String, dynamic>> decoded = favoriteStationsJson.split('|||').map((item) {
        final parts = item.split(':::');
        return <String, dynamic>{
          'stationId': parts[0],
          'stationName': parts[1],
          'stationNum': parts[2],
          'district': parts.length > 3 ? parts[3] : '',
        };
      }).toList();
      return decoded;
    } catch (_) {
      return [];
    }
  }

  Future<void> addFavoriteStation(Map<String, dynamic> station) async {
    await initialize();
    final List<Map<String, dynamic>> favorites = await getFavoriteStations();

    final bool exists = favorites.any((fav) => fav['stationId'] == station['stationId']);
    if (!exists) {
      favorites.add(station);
      final String favoritesJson = favorites.map((fav) =>
        '${fav['stationId']}:::${fav['stationName']}:::${fav['stationNum']}:::${fav['district'] ?? ''}'
      ).join('|||');
      await _prefs!.setString(_favoriteStationsKey, favoritesJson);
    }
  }

  Future<void> removeFavoriteStation(String stationId) async {
    await initialize();
    final List<Map<String, dynamic>> favorites = await getFavoriteStations();
    favorites.removeWhere((fav) => fav['stationId'] == stationId);
    final String favoritesJson = favorites.map((fav) =>
      '${fav['stationId']}:::${fav['stationName']}:::${fav['stationNum']}:::${fav['district'] ?? ''}'
    ).join('|||');
    await _prefs!.setString(_favoriteStationsKey, favoritesJson);
  }

  Future<bool> isFavoriteStation(String stationId) async {
    await initialize();
    final List<Map<String, dynamic>> favorites = await getFavoriteStations();
    return favorites.any((fav) => fav['stationId'] == stationId);
  }

  static const String _showElectiveUnavailableKey = 'show_elective_unavailable';

  Future<bool> getShowElectiveUnavailableMessage() async {
    await initialize();
    return _prefs!.getBool(_showElectiveUnavailableKey) ?? false;
  }

  Future<void> setShowElectiveUnavailableMessage(bool value) async {
    await initialize();
    await _prefs!.setBool(_showElectiveUnavailableKey, value);
  }

  static const String _scheduleCacheKey = 'schedule_cache';
  static const String _scheduleCacheTimeKey = 'schedule_cache_time';

  /// 학사일정 캐시: 3/2, 9/1이면 무조건 null 반환 → API 재요청 유도
  Future<Map<String, List<String>>?> getScheduleCache() async {
    await initialize();
    final cacheTime = _prefs!.getInt(_scheduleCacheTimeKey);
    final cacheData = _prefs!.getString(_scheduleCacheKey);
    if (cacheData == null || cacheTime == null) return null;

    final now = DateTime.now();
    if ((now.month == 3 && now.day == 2) || (now.month == 9 && now.day == 1)) {
      return null;
    }
    return _decodeScheduleCache(cacheData);
  }

  Map<String, List<String>>? _decodeScheduleCache(String data) {
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()));
    } catch (_) {
      return null;
    }
  }

  Future<void> setScheduleCache(Map<String, List<String>> data) async {
    await initialize();
    await _prefs!.setString(_scheduleCacheKey, jsonEncode(data));
    await _prefs!.setInt(_scheduleCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 3/2 또는 9/1인지 여부 (학사일정 갱신일)
  static bool get isScheduleRefreshDay {
    final now = DateTime.now();
    return (now.month == 3 && now.day == 2) || (now.month == 9 && now.day == 1);
  }

  static const String _gradeRefreshYearKey = 'grade_refresh_year';

  /// 3/2 이후, 올해 학년반 갱신을 아직 안 했으면 true
  /// - lastYear < now.year 이면 갱신 필요
  Future<bool> needsGradeRefreshThisYear() async {
    await initialize();
    final now = DateTime.now();
    if (now.month < 3 || (now.month == 3 && now.day < 2)) return false;
    final lastYear = _prefs!.getInt(_gradeRefreshYearKey) ?? 0;
    return lastYear < now.year;
  }

  Future<void> setGradeRefreshDoneForYear(int year) async {
    await initialize();
    await _prefs!.setInt(_gradeRefreshYearKey, year);
  }

  Future<void> clearCache() async {
    await initialize();
    await _prefs!.remove(_timetableCacheKey);
    await _prefs!.remove(_timetableCacheTimeKey);
    await _prefs!.remove(_mealCacheKey);
    await _prefs!.remove(_mealCacheTimeKey);
    await _prefs!.remove(_scheduleCacheKey);
    await _prefs!.remove(_scheduleCacheTimeKey);
  }

  Future<SharedPreferences> getSharedPreferences() async {
    await initialize();
    return _prefs!;
  }
}
