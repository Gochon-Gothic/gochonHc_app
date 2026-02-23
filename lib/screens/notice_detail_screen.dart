import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../theme_colors.dart';
import '../theme_provider.dart';
import '../utils/responsive_helper.dart';

class NoticeDetailScreen extends StatelessWidget {
  final Notice notice;

  const NoticeDetailScreen({
    super.key,
    required this.notice,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '공지사항',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: 20,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveHelper.padding(context, all: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: ResponsiveHelper.padding(context, all: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: ResponsiveHelper.borderRadius(context, 12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color.fromRGBO(0, 0, 0, 0.1),
                    offset: Offset(
                      0,
                      ResponsiveHelper.height(context, 2),
                    ),
                    blurRadius: ResponsiveHelper.width(context, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 22,
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  ResponsiveHelper.verticalSpace(context, 12),
                  Text(
                    notice.date,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ResponsiveHelper.verticalSpace(context, 20),
                  Divider(
                    color: secondaryTextColor.withValues(alpha: 0.2),
                    height: ResponsiveHelper.height(context, 1),
                  ),
                  ResponsiveHelper.verticalSpace(context, 20),
                  Text(
                    notice.content,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 16,
                      color: textColor,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

