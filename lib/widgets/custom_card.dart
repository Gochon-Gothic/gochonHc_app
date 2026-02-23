import 'package:flutter/material.dart';
import '../theme_colors.dart';
import '../utils/shadows.dart';
import '../utils/responsive_helper.dart';

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
