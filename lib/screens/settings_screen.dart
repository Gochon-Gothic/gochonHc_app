import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/responsive_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final currentUser = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '설정',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: 24,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: ResponsiveHelper.padding(
          context,
          horizontal: 24,
          vertical: 16,
        ),
        children: [
          // 다크모드 설정
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: ResponsiveHelper.borderRadius(context, 12),
            ),
            elevation: 4,
            color: cardColor,
            child: ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: textColor,
              ),
              title: Text(
                '다크모드',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (val) {
                  themeProvider.setDarkMode(val);
                },
                activeThumbColor: textColor,
                inactiveThumbColor: Colors.grey,
              ),
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 12),
          
          // 계정 관련 설정 (로그인 시에만 표시)
          if (currentUser != null) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: ResponsiveHelper.borderRadius(context, 12),
              ),
              elevation: 4,
              color: cardColor,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.account_circle, color: textColor),
                    title: Text(
                      '계정',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 18,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(height: ResponsiveHelper.height(context, 1)),
                  ListTile(
                    leading: Icon(Icons.email, color: textColor.withValues(alpha: 0.7)),
                    title: Text(
                      '이메일',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      currentUser.email ?? '이메일 없음',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ResponsiveHelper.verticalSpace(context, 12),
            
            // 계정 삭제 버튼
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: ResponsiveHelper.borderRadius(context, 12),
              ),
              elevation: 4,
              color: cardColor,
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                ),
                title: Text(
                  '계정 삭제',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _isDeleting
                    ? SizedBox(
                        width: ResponsiveHelper.width(context, 20),
                        height: ResponsiveHelper.height(context, 20),
                        child: CircularProgressIndicator(
                          strokeWidth: ResponsiveHelper.width(context, 2),
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: ResponsiveHelper.width(context, 16),
                        color: Colors.red,
                      ),
                onTap: _isDeleting ? null : _showDeleteAccountDialog,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: bgColor,
          title: Text(
            '계정 삭제',
            style: TextStyle(color: textColor),
          ),
          content: Text(
            '정말 계정을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 모든 데이터가 영구적으로 삭제됩니다.',
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(color: textColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              child: const Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;
    
    setState(() {
      _isDeleting = true;
    });

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      // Firestore에서 사용자 데이터 삭제
      await AuthService.instance.deleteAccount();
      
      // 로컬 사용자 정보 삭제
      await UserService.instance.clearUserInfo();

      if (!mounted) return;
      
      // 모든 화면을 제거하고 로그인 화면으로 이동
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계정이 삭제되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정 삭제 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

