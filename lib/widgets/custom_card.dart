import 'package:flutter/material.dart';
import '../theme_colors.dart';
import '../utils/shadows.dart';
import '../utils/responsive_helper.dart';

/// 카드형 컨테이너 위젯
///
/// [로직 흐름]
/// 1. backgroundColor 없으면 isDark에 따라 darkCard/lightCard 사용
/// 2. margin 없으면 세로 6 비율, borderRadius 없으면 12 비율
/// 3. AppShadows.card(isDark)로 그림자 적용
/// 4. onTap 있으면 Material+InkWell로 감싸서 탭 반응, 없으면 Container만 반환
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool isDark;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        backgroundColor ?? (isDark ? AppColors.darkCard : AppColors.lightCard);

    final card = Container(
      margin: margin ?? EdgeInsets.symmetric(
        vertical: ResponsiveHelper.height(context, 6),
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius ?? ResponsiveHelper.borderRadius(context, 12),
        boxShadow: AppShadows.card(isDark),
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? ResponsiveHelper.borderRadius(context, 12),
          child: card,
        ),
      );
    }

    return card;
  }
}
