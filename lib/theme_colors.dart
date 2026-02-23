import 'package:flutter/material.dart';

/// 앱 전체 색상 상수 정의
///
/// [구조]
/// 1. primary: 기본 강조색 (검정)
/// 2. light*: 라이트 모드용 (배경, 카드, 텍스트, 테두리 등)
/// 3. dark*: 다크 모드용
/// 4. success/warning/error/info: 상태 표시용
/// 5. grey50~grey900: 그레이 스케일
/// 6. secondary, accent: 보조 색상
class AppColors {
  static const Color primary = Color(0xFF000000);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightBorder = Color(0xFFDFDFDF);
  static const Color lightSecondaryText = Color(0xFF828282);
  static const Color lightDivider = Color(0xFFE6E6E6);
  static const Color lightNavSelected = Color(0xFF000000);
  static const Color lightNavUnselected = Color(0xFF828282);
  static const Color lightError = Color(0xFFEF4444);

  static const Color darkBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkSecondaryText = Color(0xFF828282);
  static const Color darkDivider = Color(0xFF2A2A2A);
  static const Color darkNavSelected = Color(0xFFFFFFFF);
  static const Color darkNavUnselected = Color(0xFF828282);
  static const Color darkError = Color(0xFFEF4444);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color.fromARGB(255, 203, 204, 208);

  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFE6E6E6);
  static const Color grey300 = Color(0xFFDFDFDF);
  static const Color grey400 = Color(0xFF828282);
  static const Color grey500 = Color(0xFF6B6B6B);
  static const Color grey600 = Color(0xFF4B4B4B);
  static const Color grey700 = Color(0xFF333333);
  static const Color grey800 = Color(0xFF1A1A1A);
  static const Color grey900 = Color(0xFF000000);

  static const Color secondary = Color(0xFF6B7280);
  static const Color accent = Color.fromARGB(255, 203, 204, 208);

  static const Map<String, Color> colorMap = {
    'primary': primary,
    'secondary': secondary,
    'accent': accent,
  };
}
