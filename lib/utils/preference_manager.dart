import 'package:shared_preferences/shared_preferences.dart';

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

  Future<Map<String, dynamic>?> getTimetableCache() async {
    await initialize();
    final cacheTime = _prefs!.getInt(_timetableCacheTimeKey);
    if (cacheTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTime < 3600000) {
        final cacheData = _prefs!.getString(_timetableCacheKey);
        if (cacheData != null) {
          return Map<String, dynamic>.from(cacheData as Map<String, dynamic>);
        }
      }
    }
    return null;
  }

  Future<void> setTimetableCache(Map<String, dynamic> data) async {
    await initialize();
    await _prefs!.setString(_timetableCacheKey, data.toString());
    await _prefs!.setInt(
      _timetableCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static const String _mealCacheKey = 'meal_cache';
  static const String _mealCacheTimeKey = 'meal_cache_time';

  Future<Map<String, dynamic>?> getMealCache() async {
    await initialize();
    final cacheTime = _prefs!.getInt(_mealCacheTimeKey);
    if (cacheTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTime < 259200000) {
        final cacheData = _prefs!.getString(_mealCacheKey);
        if (cacheData != null) {
          return Map<String, dynamic>.from(cacheData as Map<String, dynamic>);
        }
      }
    }
    return null;
  }

  Future<void> setMealCache(Map<String, dynamic> data) async {
    await initialize();
    await _prefs!.setString(_mealCacheKey, data.toString());
    await _prefs!.setInt(
      _mealCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static const String _favoriteStationsKey = 'favorite_stations';

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
    } catch (e) {
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

  Future<void> clearCache() async {
    await initialize();
    await _prefs!.remove(_timetableCacheKey);
    await _prefs!.remove(_timetableCacheTimeKey);
    await _prefs!.remove(_mealCacheKey);
    await _prefs!.remove(_mealCacheTimeKey);
  }

  Future<SharedPreferences> getSharedPreferences() async {
    await initialize();
    return _prefs!;
  }
}
