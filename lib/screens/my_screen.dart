import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool isLoading = false;
  String? error;
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
          const SizedBox(height: 32),
          Text(
            '마이',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,

            ),
          ),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 40,
            backgroundColor: cardColor,
            child: Icon(Icons.person, size: 50, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            userInfo?.name ?? '사용자',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            userInfo != null
                ? '${userInfo!.grade}학년 ${userInfo!.classNum}반 ${userInfo!.number}번'
                : '정보를 불러오는 중...',
            style: TextStyle(fontSize: 16, color: textColor),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  color: cardColor,
                  child: ListTile(
                    leading: Icon(Icons.settings, color: textColor),
                    title: Text('설정', style: TextStyle(color: textColor)),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textColor,
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true, // 스크롤 가능하게 설정
                        builder: (context) {
                          return DraggableScrollableSheet(
                            initialChildSize: 0.6, // 초기 높이를 화면의 60%로 설정
                            minChildSize: 0.4, // 최소 높이를 화면의 40%로 설정
                            maxChildSize: 0.9, // 최대 높이를 화면의 90%로 설정
                            builder: (context, scrollController) {
                              return Container(
                                color: cardColor,
                                padding: const EdgeInsets.all(24),
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '설정',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (userInfo != null &&
                                          userInfo!.name != '게스트')
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '사용자 정보',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              decoration: InputDecoration(
                                                labelText: '이름',
                                                labelStyle: TextStyle(
                                                  color: textColor,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: textColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      ),
                                                    ),
                                              ),
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                              controller: TextEditingController(
                                                text: userInfo!.name ?? '',
                                              ),
                                              onChanged: (value) async {
                                                await UserService.instance
                                                    .updateUserName(value);
                                                _loadUserInfo(); // UI 새로고침
                                              },
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                        ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '다크모드',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: textColor,
                                            ),
                                          ),
                                          Switch(
                                            value: themeProvider.isDarkMode,
                                            onChanged: (val) {
                                              themeProvider.setDarkMode(val);
                                              Navigator.pop(context);
                                            },
                                            activeThumbColor: textColor,
                                            inactiveThumbColor: Colors.grey,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        '추가 설정',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '추후 더 많은 설정 옵션이 추가될 예정입니다.',
                                        style: TextStyle(
                                          color: textColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  color: cardColor,
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: textColor),
                    title: Text('앱 정보', style: TextStyle(color: textColor)),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textColor,
                    ),
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  color: cardColor, // 다른 버튼들과 동일한 색상
                  child: ListTile(
                    leading: Icon(Icons.logout, color: textColor),
                    title: Text(
                      '로그아웃',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textColor,
                    ),
                    onTap: () {
                      _showLogoutDialog();
                    },
                  ),
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
    setState(() {
      isLoading = true;
    });

    try {
      final isGuest = await UserService.instance.isGuestMode();

      if (isGuest) {
        if (!mounted) return;
        setState(() {
          userInfo = UserInfo(
            email: 'guest@gochon.hs.kr',
            grade: 1,
            classNum: 1,
            number: 1,
            name: '게스트',
          );
          isLoading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final name = prefs.getString('user_name');
      final grade = prefs.getString('user_grade');
      final className = prefs.getString('user_class');
      final numberStr = prefs.getString('user_number');
      final hasSetup = prefs.getBool('user_has_setup') ?? false;

      if (!mounted) return;

      if (email != null &&
          hasSetup &&
          name != null &&
          grade != null &&
          className != null &&
          numberStr != null) {
        final userGrade = int.tryParse(grade) ?? 1;
        final userClass = int.tryParse(className) ?? 1;
        final userNumber = int.tryParse(numberStr) ?? 1;

        setState(() {
          userInfo = UserInfo(
            email: email,
            grade: userGrade,
            classNum: userClass,
            number: userNumber,
            name: name,
          );
          isLoading = false;
        });
      } else if (email != null) {
        setState(() {
          userInfo = UserInfo.fromEmail(email);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
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
          title: Text('로그아웃', style: TextStyle(color: textColor)),
          content: Text('정말 로그아웃 하시겠습니까?', style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소', style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      await UserService.instance.clearUserInfo();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }
}
