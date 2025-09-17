import 'package:flutter/material.dart';
import '../theme_colors.dart';
import '../utils/shadows.dart';

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
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        boxShadow: AppShadows.card(isDark),
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: card,
        ),
      );
    }

    return card;
  }
}

class CustomListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDark;
  final Color? textColor;

  const CustomListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    required this.isDark,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextColor =
        textColor ?? (isDark ? AppColors.darkText : AppColors.lightText);

    return ListTile(
      leading: leading,
      title: DefaultTextStyle(
        style: TextStyle(color: defaultTextColor),
        child: title,
      ),
      subtitle:
          subtitle != null
              ? DefaultTextStyle(
                style: TextStyle(
                  color: defaultTextColor.withValues(alpha: 0.7),
                ),
                child: subtitle!,
              )
              : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
