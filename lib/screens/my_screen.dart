import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth_pkg; 
import 'settings_screen.dart';
import '../utils/responsive_helper.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  UserInfo? userInfo;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    return Container(
      color: bgColor,
      child: Column(
        children: [
          ResponsiveHelper.verticalSpace(context, 80),
          Text(
            '마이',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 12),
          CircleAvatar(
            radius: ResponsiveHelper.width(context, 40),
            backgroundColor: cardColor,
            child: Icon(
              Icons.person,
              size: ResponsiveHelper.width(context, 50),
              color: textColor,
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 12),
          Text(
            AuthService.instance.currentUser == null
                ? '게스트'
                : (userInfo?.name ?? '사용자'),
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            AuthService.instance.currentUser == null
                ? ''
                : (userInfo != null
                    ? '${userInfo?.grade ?? ''}학년 ${userInfo?.classNum ?? ''}반 ${userInfo?.number ?? ''}번'
                    : '정보를 불러오는 중...'),
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 16,
              color: textColor,
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 24),
          Expanded(
            child: ListView(
              padding: ResponsiveHelper.horizontalPadding(context, 24),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: ResponsiveHelper.borderRadius(context, 12),
                  ),
                  elevation: 4,
                  color: cardColor,
                  child: ListTile(
                    leading: Icon(
                      Icons.settings,
                      color: textColor,
                    ),
                    title: Text(
                      '설정',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: ResponsiveHelper.width(context, 16),
                      color: textColor,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                ResponsiveHelper.verticalSpace(context, 12),
                StreamBuilder<firebase_auth_pkg.User?>(
                  stream: AuthService.instance.authStateChanges,
                  builder: (context, snapshot) {
                    // 로그인 상태가 변경되면 userInfo 업데이트
                    if (snapshot.hasData) {
                      // 로그인된 상태: 사용자 정보 다시 로드
                      if (userInfo == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadUserInfo();
                        });
                      }
                    } else {
                      // 로그아웃된 상태: userInfo 즉시 초기화
                      if (userInfo != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              userInfo = null;
                            });
                          }
                        });
                      }
                    }
                    
                    if (snapshot.hasData) {
                      // 로그인된 상태: 로그아웃 버튼 표시
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: ResponsiveHelper.borderRadius(context, 12),
                        ),
                        elevation: 4,
                        color: cardColor,
                        child: ListTile(
                          leading: Icon(Icons.logout, color: textColor),
                          title: Text(
                            '로그아웃',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 16,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: ResponsiveHelper.width(context, 16),
                            color: textColor,
                          ),
                          onTap: () {
                            _showLogoutDialog();
                          },
                        ),
                      );
                    } else {
                      // 로그아웃된 상태: 로그인 버튼 표시
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: ResponsiveHelper.borderRadius(context, 12),
                        ),
                        elevation: 4,
                        color: cardColor,
                        child: ListTile(
                          leading: Icon(Icons.login, color: textColor),
                          title: Text(
                            '로그인',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 16,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: ResponsiveHelper.width(context, 16),
                            color: textColor,
                          ),
                          onTap: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                          },
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    if (!mounted) return;

    try {
      final loadedUserInfo = await UserService.instance.getUserInfo();
      if (mounted) {
        setState(() {
          userInfo = loadedUserInfo;
        });
      }
    } catch (e) {
      // 에러 발생 시 무시 (UI에 표시하지 않음)
    }
  }

  void _showLogoutDialog() {
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
            '로그아웃',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 20,
              color: textColor,
            ),
          ),
          content: Text(
            '정말 로그아웃 하시겠습니까?',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 16,
              color: textColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: Text(
                '로그아웃',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    if (!mounted) return;

    try {
      await AuthService.instance.signOut();
      // AuthWrapper가 로그인 상태 변화를 감지하여 자동으로 화면 전환을 처리
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그아웃 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
