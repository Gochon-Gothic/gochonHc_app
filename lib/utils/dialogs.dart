import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import 'responsive_helper.dart';

void showElectiveUnavailableModal(BuildContext context) {
  final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
  final bgColor = isDark ? AppColors.darkCard : AppColors.lightCard;
  final textColor = isDark ? AppColors.darkText : AppColors.lightText;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '현재 선택과목 정보가 존재하지 않아\n선택할 수 없습니다\n이후에 다시 선택해주세요',
            textAlign: TextAlign.center,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 16,
              color: textColor,
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.lightBackground : AppColors.primary,
                foregroundColor: isDark ? AppColors.primary : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '계속하기',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
