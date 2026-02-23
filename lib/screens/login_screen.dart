import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/user_info.dart';

/// 로그인 화면: Google/Apple 소셜 로그인
///
/// [로직 흐름]
/// 1. _handleGoogleSignIn: signInWithGoogle → checkUserExists → 있으면 getUserFromFirestore, saveUserInfo → MainScreen
///    - 없으면 InitialSetupScreen(userEmail, uid)
/// 2. _handleAppleSignIn: 동일 패턴
/// 3. 로그인 취소 시 isLoading=false만 설정
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme_colors.dart';
import '../theme_provider.dart';
import 'initial_setup_screen.dart';
import '../main.dart';
import '../utils/responsive_helper.dart';

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
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainScreen(),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => InitialSetupScreen(
                  userEmail: user.email ?? '',
                  uid: user.uid,
                ),
              ),
            );
          }
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
  Future<void> _handleAppleSignIn() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final userCredential = await AuthService.instance.signInWithApple();

      if (userCredential != null && mounted) {
        final user = userCredential.user!;
        final userExists = await AuthService.instance.checkUserExists(user.uid);

        if (userExists) {
          final userData = await AuthService.instance.getUserFromFirestore(user.uid);
          if (userData != null) {
            final userInfo = UserInfo.fromJson(userData);
            await UserService.instance.saveUserInfo(userInfo);
          }
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainScreen(),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => InitialSetupScreen(
                  userEmail: user.email ?? '',
                  uid: user.uid,
                ),
              ),
            );
          }
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

  Future<void> _handleGuestLogin() async {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
      );
    }
  }

  /// Apple 가이드라인: 제목과 버튼 오른쪽 가장자리 사이 최소 8% 여백
  Widget _buildAppleSignInButton(BuildContext context, bool isDark, bool isLoading) {
    final buttonWidth = ResponsiveHelper.width(context, 327);
    const minMarginPercent = 0.08;
    final horizontalPadding = buttonWidth * minMarginPercent; // 8% 이상

    final logoColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.black : Colors.white;
    final backgroundColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      width: buttonWidth,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isLoading ? null : _handleAppleSignIn,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: SvgPicture.asset(
                      'assets/images/apple.svg',
                      semanticsLabel: 'Apple Logo',
                      colorFilter: ColorFilter.mode(
                        logoColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sign in with Apple',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Apple 버튼과 동일한 비율: 327x50, fontSize 16, 8% 여백
  Widget _buildGoogleSignInButton(BuildContext context, bool isDark, bool isLoading) {
    final buttonWidth = ResponsiveHelper.width(context, 327);
    final horizontalPadding = buttonWidth * 0.08;
    final textColor = isDark ? Colors.black : Colors.white;
    final backgroundColor = isDark ? Colors.white : AppColors.primary;

    return SizedBox(
      width: buttonWidth,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isLoading ? null : _handleGoogleSignIn,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Apple 버튼과 동일한 비율: 327x50, fontSize 16, 8% 여백
  Widget _buildGuestLoginButton(BuildContext context, bool isDark, bool isLoading) {
    final buttonWidth = ResponsiveHelper.width(context, 327);
    final horizontalPadding = buttonWidth * 0.08;
    final textColor = isDark ? Colors.black : Colors.white;
    final backgroundColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      width: buttonWidth,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isLoading ? null : _handleGuestLogin,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(
                child: Text(
                  '로그인 없이 이용하기',
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

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
                  top: ResponsiveHelper.height(context, 60),
                  left: 0,
                  right: 0,
                  child: Text(
                    '로그인하기',
                    textAlign: TextAlign.center,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 50,
                      color: textColor,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),

                Positioned(
                  top: ResponsiveHelper.height(context, 210),
                  left: ResponsiveHelper.width(context, 13),
                  right: ResponsiveHelper.width(context, 13),
                  child: Container(
                    padding: ResponsiveHelper.padding(
                      context,
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
                              '소셜 계정을 이용해 로그인',
                              textAlign: TextAlign.center,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 16,
                                color: textColor,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            ResponsiveHelper.verticalSpace(context, 2),
                            Text(
                              'Login by using social account',
                              textAlign: TextAlign.center,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 14,
                                color: textColor,
                                letterSpacing: 0,
                                fontWeight: FontWeight.normal,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),

                        ResponsiveHelper.verticalSpace(context, 24),

                        _buildGoogleSignInButton(context, isDark, isLoading),
                        ResponsiveHelper.verticalSpace(context, 20),
                        _buildAppleSignInButton(context, isDark, isLoading),
                        ResponsiveHelper.verticalSpace(context, 32),
                        SizedBox(
                          width: ResponsiveHelper.width(context, 327),
                          height: ResponsiveHelper.height(context, 1),
                          child: Container(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : secondaryTextColor,
                          ),
                        ),
                        ResponsiveHelper.verticalSpace(context, 32),
                        _buildGuestLoginButton(context, isDark, isLoading),

                        ResponsiveHelper.verticalSpace(context, 24),

                        Text(
                          'By clicking sign in, you agree to our Terms of Service and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 12,
                            color: secondaryTextColor,
                            letterSpacing: 0,
                            fontWeight: FontWeight.normal,
                            height: 1.5,
                          ),
                        ),

                        if (error != null) ...[
                          ResponsiveHelper.verticalSpace(context, 16),
                          Text(
                            error!,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: ResponsiveHelper.height(context, 70),
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '고촌고등학교',
                        textAlign: TextAlign.center,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 25,
                          color: textColor,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              offset: Offset(
                                ResponsiveHelper.width(context, 0.5),
                                ResponsiveHelper.height(context, 0.5),
                              ),
                              blurRadius: ResponsiveHelper.width(context, 0.5),
                              color: textColor.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                      ResponsiveHelper.horizontalSpace(context, 8),
                      SizedBox(
                        width: ResponsiveHelper.width(context, 23),
                        height: ResponsiveHelper.height(context, 23),
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
