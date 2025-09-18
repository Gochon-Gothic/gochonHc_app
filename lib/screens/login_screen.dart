import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_service.dart';
import '../theme_colors.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String? error;

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        error = '이메일을 입력해주세요.';
      });
      return;
    }

    if (!email.endsWith('@gochon.hs.kr')) {
      setState(() {
        error = '고촌고등학교 이메일(@gochon.hs.kr)을 사용해주세요.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);

      final hasSetup = prefs.getBool('user_has_setup') ?? false;

      if (mounted) {
        if (hasSetup) {
          Navigator.pushReplacementNamed(context, '/main');
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/initial_setup',
            arguments: {'userEmail': email},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '로그인 중 오류가 발생했습니다.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
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
                      
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 327,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: bgColor,
                              border: Border.all(
                                color: borderColor,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                hintText: '25-20504@gochon.hs.kr',
                                hintStyle: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  height: 1.5,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                height: 1.5,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
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
                                onTap: isLoading ? null : _handleLogin,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Center(
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Continue',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isDark ? Colors.black : Colors.white,
                                              fontSize: 14,
                                              letterSpacing: 0,
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 148.5,
                            height: 1,
                            decoration: BoxDecoration(
                              color: dividerColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'or',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                              letterSpacing: 0,
                              fontWeight: FontWeight.normal,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 148.5,
                            height: 1,
                            decoration: BoxDecoration(
                              color: dividerColor,
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
                            onTap: () {
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      color: isDark ? Colors.black : Colors.white,
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
                      
                      const SizedBox(height: 24),
                      
                      GestureDetector(
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await UserService.instance.setGuestMode(true);
                          if (mounted) {
                            navigator.pushReplacementNamed('/main');
                          }
                        },
                        child: Text(
                          '로그인하지않고 이용하기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            height: 1.5,
                            decoration: TextDecoration.underline,
                            decorationColor: secondaryTextColor,
                          ),
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
    emailController.dispose();
    super.dispose();
  }
}
