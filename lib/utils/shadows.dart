import 'package:flutter/material.dart';
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
  static Color painterShadowColor(bool isDark) =>
      isDark ? Colors.black.withValues(alpha: 0.20) : const Color.fromRGBO(0, 0, 0, 0.12);
}