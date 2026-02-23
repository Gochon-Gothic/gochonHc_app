import 'package:flutter/material.dart';

/// 카드용 그림자 스타일
///
/// [로직]
/// - card(isDark): 다크 모드면 검정 20% 투명, 라이트면 검정 12% 투명
/// - offset (0,2), blur 6, spread 0
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.20)
              : const Color.fromRGBO(0, 0, 0, 0.12),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];
}
