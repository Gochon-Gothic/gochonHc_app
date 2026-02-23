import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 라이트/다크 테마 상태 관리
///
/// [로직 흐름]
/// 1. 생성자 → _initializeTheme() 비동기 호출
/// 2. _initializeTheme:
///    - 이미 초기화됐으면 즉시 반환
///    - SharedPreferences에서 first_run, theme_mode 읽기
///    - first_run이 true → 다크 모드로 설정 후 first_run=false 저장
///    - first_run이 false → 저장된 theme_mode 사용 (기본 다크)
///    - 초기화 완료 후 notifyListeners()
/// 3. setDarkMode(value):
///    - 현재 값과 같으면 무시
///    - _isDarkMode 갱신 → SharedPreferences 저장 → notifyListeners()
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _firstRunKey = 'first_run';

  bool _isDarkMode = false;
  bool _isFirstRun = true;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isFirstRun => _isFirstRun;

  ThemeProvider() {
    _initializeTheme();
  }

  /// SharedPreferences에서 테마 로드
  /// - 첫 실행: 다크 모드 고정, first_run 플래그 저장
  /// - 이후: 저장된 theme_mode 사용
  Future<void> _initializeTheme() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isFirstRun = prefs.getBool(_firstRunKey) ?? true;

      if (_isFirstRun) {
        _isDarkMode = true;
        await prefs.setBool(_firstRunKey, false);
        await prefs.setBool(_themeKey, _isDarkMode);
      } else {
        _isDarkMode = prefs.getBool(_themeKey) ?? true;
      }

      _isInitialized = true;
      notifyListeners();
    } catch (_) {
      _isDarkMode = true;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 테마 변경 시 호출
  /// - 값이 동일하면 early return
  /// - SharedPreferences에 저장 후 notifyListeners()
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, value);
    } catch (_) {}

    notifyListeners();
  }
}
