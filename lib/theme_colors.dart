import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - 검은색 기반 미니멀 디자인
  static const Color primary = Color(0xFF000000); // Pure Black
  
  // Light theme colors - 깔끔한 흰색 배경
  static const Color lightBackground = Color(0xFFFFFFFF); // Pure White
  static const Color lightCard = Color(0xFFFFFFFF); // Pure White
  static const Color lightText = Color(0xFF000000); // Pure Black
  static const Color lightBorder = Color(0xFFDFDFDF); // Light Grey Border
  static const Color lightSecondaryText = Color(0xFF828282); // Medium Grey
  static const Color lightDivider = Color(0xFFE6E6E6); // Light Grey Divider
  static const Color lightNavSelected = Color(0xFF000000); // Black
  static const Color lightNavUnselected = Color(0xFF828282); // Medium Grey
  static const Color lightError = Color(0xFFEF4444);
  
  // Dark theme colors - 다크 모드용
  static const Color darkBackground = Color(0xFF000000); // Pure Black
  static const Color darkCard = Color(0xFF1A1A1A); // Very Dark Grey
  static const Color darkText = Color(0xFFFFFFFF); // Pure White
  static const Color darkBorder = Color(0xFF333333); // Dark Grey Border
  static const Color darkSecondaryText = Color(0xFF828282); // Medium Grey
  static const Color darkDivider = Color(0xFF2A2A2A); // Dark Grey Divider
  static const Color darkNavSelected = Color(0xFFFFFFFF); // White
  static const Color darkNavUnselected = Color(0xFF828282); // Medium Grey
  static const Color darkError = Color(0xFFEF4444);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color.fromARGB(255, 203, 204, 208);
  
  // Neutral colors - 미니멀 그레이 팔레트
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
  
  // 공통 색상
  static const Color secondary = Color(0xFF6B7280);
  static const Color accent = Color.fromARGB(255, 203, 204, 208);
  
  // 성능 최적화를 위한 색상 맵
  static const Map<String, Color> colorMap = {
    'primary': primary,
    'secondary': secondary,
    'accent': accent,
  };
}