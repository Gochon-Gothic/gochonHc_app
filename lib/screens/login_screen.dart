import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_info.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../theme_colors.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  String? error;


  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final userCredential = await AuthService.instance.signInWithGoogle();

      if (userCredential != null && mounted) {
        final user = userCredential.user!;

        // Firestore에 사용자 문서가 존재하는지 확인
        final userExists = await AuthService.instance.checkUserExists(user.uid);

        if (userExists) {
          // Firestore에서 최신 사용자 정보를 가져와 로컬에 저장
          final userData = await AuthService.instance.getUserFromFirestore(user.uid);
          if (userData != null) {
            final userInfo = UserInfo.fromJson(userData);
            await UserService.instance.saveUserInfo(userInfo);
          }
          Navigator.pushReplacementNamed(context, '/main');
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/initial_setup',
            arguments: {'userEmail': user.email, 'uid': user.uid},
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final dividerColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bgColor,
      body: MediaQuery.removeViewInsets(
        removeBottom: true,
        context: context,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Text(
                    '로그인하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 50,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),

                Positioned(
                  top: 210,
                  left: 13,
                  right: 13,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '학교 구글 계정을 통해 로그인',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Login by using school google account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                letterSpacing: 0,
                                fontWeight: FontWeight.normal,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Container(
                          width: 327,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: isLoading ? null : _handleGoogleSignIn,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: SvgPicture.asset(
                                        'assets/images/google_logo.svg',
                                        semanticsLabel: 'Google Logo',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Continue with Google',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.black
                                                : Colors.white,
                                        fontSize: 14,
                                        letterSpacing: 0,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'By clicking continue, you agree to our Terms of Service and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                            letterSpacing: 0,
                            fontWeight: FontWeight.normal,
                            height: 1.5,
                          ),
                        ),

                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            error!,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 70,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '고촌고등학교',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 25,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          shadows: [
                            Shadow(
                              offset: const Offset(0.5, 0.5),
                              blurRadius: 0.5,
                              color: textColor.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 23,
                        height: 23,
                        child: SvgPicture.asset(
                          'assets/images/gochon_logo.svg',
                          semanticsLabel: 'Gochon Logo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
