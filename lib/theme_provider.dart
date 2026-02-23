import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _firstRunKey = 'first_run';

  bool _isDarkMode = false;
  bool _isFirstRun = true;
  bool _isInitialized = false;

  // 게터로 한 번만 계산하도록 최적화
  bool get isDarkMode => _isDarkMode;
  bool get isFirstRun => _isFirstRun;

  ThemeProvider() {
    _initializeTheme();
  }

  // 지연 초기화로 앱 시작 시 렉 방지
  Future<void> _initializeTheme() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isFirstRun = prefs.getBool(_firstRunKey) ?? true;

      if (_isFirstRun) {
        // 첫 실행 시 다크 모드로 설정
        _isDarkMode = true;
        await prefs.setBool(_firstRunKey, false);
        await prefs.setBool(_themeKey, _isDarkMode);
      } else {
        // 저장된 테마 불러오기
        _isDarkMode = prefs.getBool(_themeKey) ?? true; // 기본값을 다크 모드로
      }

      _isInitialized = true;
      // 초기화 완료 후에만 notify
      notifyListeners();
    } catch (_) {
      // 에러 시 다크 모드를 기본값으로 사용
      _isDarkMode = true;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 테마 변경 시에만 notifyListeners 호출
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return; // 동일한 값이면 변경하지 않음

    _isDarkMode = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, value);
    } catch (_) {
      // 에러 발생 시에도 UI는 업데이트
    }

    notifyListeners();
  }
}
