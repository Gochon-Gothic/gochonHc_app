import 'package:flutter/material.dart';

import '../models/user_info.dart';
import '../services/user_service.dart';
// import '../services/gsheet_service.dart'; Firebase 대체(25.09.20)
import '../theme_colors.dart';

class InitialSetupScreen extends StatefulWidget {
  final String userEmail;
  final String uid;

  const InitialSetupScreen(
      {super.key, required this.userEmail, required this.uid});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _classController = TextEditingController();
  final _studentNumberController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _classController.dispose();
    _studentNumberController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. UserInfo 객체 생성
      final userInfo = UserInfo(
        email: widget.userEmail,
        name: _nameController.text.trim(),
        grade: int.parse(_gradeController.text.trim()),
        classNum: int.parse(_classController.text.trim()),
        number: int.parse(_studentNumberController.text.trim()),
      );

      // 2. Firestore에 사용자 정보 저장
      await UserService.instance.saveUserToFirebase(
        uid: widget.uid,
        email: userInfo.email,
        name: userInfo.name,
        grade: userInfo.grade,
        classNum: userInfo.classNum,
        number: userInfo.number,
      );

      // 3. 로컬(SharedPreferences)에 사용자 정보 저장
      await UserService.instance.saveUserInfo(userInfo);

      // 4. 메인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('설정 저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 환영 메시지
                Text(
                  '환영합니다',
                  style: TextStyle(
                    color: textColor,

                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 35),

                // 학년 입력
                Text(
                  '학년',
                  style: TextStyle(
                    color: textColor,

                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gradeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '학년을 입력하세요(숫자만)',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(color: textColor, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '학년을 입력해주세요';
                    }
                    final grade = int.tryParse(value.trim());
                    if (grade == null || grade < 1 || grade > 3) {
                      return '학년은 1, 2, 3 중 하나여야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 반 입력
                Text(
                  '반',
                  style: TextStyle(
                    color: textColor,

                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _classController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '반을 입력하세요(숫자만)',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(color: textColor, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '반을 입력해주세요';
                    }
                    final classNum = int.tryParse(value.trim());
                    if (classNum == null || classNum < 1 || classNum > 11) {
                      return '반은 1부터 11까지의 숫자여야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 번호 입력
                Text(
                  '번호',
                  style: TextStyle(
                    color: textColor,

                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText:
                        '번호를 입력하세요(숫자만)',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(color: textColor, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '번호를 입력해주세요';
                    }
                    final studentNum = int.tryParse(value.trim());
                    if (studentNum == null ||
                        studentNum < 1 ||
                        studentNum > 40) {
                      return '번호는 1부터 45까지의 숫자여야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 이름 입력
                Text(
                  '이름',
                  style: TextStyle(
                    color: textColor,

                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '이름을 입력하세요',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(color: textColor, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요';
                    }
                    if (value.trim().length < 2) {
                      return '이름은 2글자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '*부적절한 이름을 사용할 경우, 제제가 부과될 수 있습니다*',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 30),

                // 선택과목 정보 (나중에 구현)
                Text(
                  '선택과목 정보',
                  style: TextStyle(
                    color: textColor,

                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '선택과목 기능은 추후 구현 예정입니다.',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),

                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                // 완료 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.lightBackground : AppColors.primary,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              '설정 완료',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
