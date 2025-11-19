import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth_pkg; 
import 'initial_setup_screen.dart';

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
                ? '${userInfo?.grade ?? ''}학년 ${userInfo?.classNum ?? ''}반 ${userInfo?.number ?? ''}번'
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
                                                text: userInfo?.name ?? '',
                                              ),
                                              onChanged: (value) async {
                                                await UserService.instance
                                                    .updateUserName(value);
                                                _loadUserInfo(); // UI 새로고침
                                              },
                                            ),
                                            const SizedBox(height: 20),
                                            // 인적사항 수정하기 버튼
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pop(context); // 설정 모달 닫기
                                                  final currentUser = AuthService.instance.currentUser;
                                                  if (currentUser != null && userInfo != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => InitialSetupScreen(
                                                          userEmail: currentUser.email ?? '',
                                                          uid: currentUser.uid,
                                                          existingUserInfo: userInfo,
                                                        ),
                                                      ),
                                                    ).then((_) {
                                                      // 수정 후 돌아왔을 때 사용자 정보 새로고침
                                                      _loadUserInfo();
                                                    });
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Text(
                                                  '인적사항 수정하기',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
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
                StreamBuilder<firebase_auth_pkg.User?>(
                  stream: AuthService.instance.authStateChanges,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      // 로그인된 상태: 로그아웃 버튼 표시
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        color: cardColor,
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
                      );
                    } else {
                      // 로그아웃된 상태: 로그인 버튼 표시
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        color: cardColor,
                        child: ListTile(
                          leading: Icon(Icons.login, color: textColor),
                          title: Text(
                            '로그인',
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
                            Navigator.pushReplacementNamed(context, '/login');
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
    setState(() {
      isLoading = true;
    });

    try {
      final loadedUserInfo = await UserService.instance.getUserInfo();
      if (mounted) {
        setState(() {
          userInfo = loadedUserInfo;
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
      await AuthService.instance.signOut(); // Firebase 로그아웃 호출

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      // AuthWrapper가 로그인 상태 변화를 감지하여 자동으로 화면 전환을 처리하므로, 여기서 직접 /login으로 이동할 필요 없음
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }
}
