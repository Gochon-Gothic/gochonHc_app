import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/user_info.dart';
import '../services/user_service.dart';
import '../theme_colors.dart';
import 'elective_setup_screen.dart';

class InitialSetupScreen extends StatefulWidget {
  final String userEmail;
  final String uid;
  final UserInfo? existingUserInfo; // 수정 모드를 위한 기존 사용자 정보

  const InitialSetupScreen({
    super.key,
    required this.userEmail,
    required this.uid,
    this.existingUserInfo,
  });

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
  void initState() {
    super.initState();
    // 수정 모드인 경우 기존 정보로 컨트롤러 초기화
    if (widget.existingUserInfo != null) {
      _nameController.text = widget.existingUserInfo!.name;
      _gradeController.text = widget.existingUserInfo!.grade.toString();
      _classController.text = widget.existingUserInfo!.classNum.toString();
      _studentNumberController.text = widget.existingUserInfo!.number.toString();
    }
  }

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
      await UserService.instance.saveUserInfo(userInfo);
      _preloadTimetables(userInfo.grade, userInfo.classNum);

      // 학년에 따라 분기
      if (userInfo.grade == 1) {
        // 1학년: 바로 메인 화면으로 또는 설정 화면으로
        if (mounted) {
          if (widget.existingUserInfo != null) {
            Navigator.of(context).pop(); // 수정 모드: 설정 화면으로 돌아가기
          } else {
            Navigator.of(context).pushReplacementNamed('/main');
          }
        }
      } else {
        // 2-3학년: 선택과목 선택 페이지로
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ElectiveSetupScreen(
                userEmail: widget.userEmail,
                uid: widget.uid,
                grade: userInfo.grade,
                classNum: userInfo.classNum,
                isEditMode: widget.existingUserInfo != null, // 수정 모드 플래그 전달
              ),
            ),
          );
        }
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

  void _preloadTimetables(int grade, int classNum) {
    // 비동기로 백그라운드에서 실행 (await 하지 않음)
    Future.microtask(() async {
      try {
        const apiKey = '2cf24c119b434f93b2f916280097454a';
        const eduOfficeCode = 'J10';
        const schoolCode = '7531375';

        final now = DateTime.now().toUtc().add(const Duration(hours: 9));
        final weekday = now.weekday;

        // 이번주 월요일 계산
        DateTime thisWeekStart;
        if (weekday >= 6) {
          thisWeekStart = now.add(Duration(days: 8 - weekday));
        } else {
          thisWeekStart = now.subtract(Duration(days: weekday - 1));
        }

        // 다음주 월요일 계산
        final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

        final formatter = DateFormat('yyyyMMdd');
        final thisWeekEnd = thisWeekStart.add(const Duration(days: 4));
        final nextWeekEnd = nextWeekStart.add(const Duration(days: 4));

        // timetable_screen.dart와 동일한 방식으로 API 호출
        // 이번주 시간표 프리로딩
        try {
          final thisWeekUrl = Uri.parse(
            'https://open.neis.go.kr/hub/hisTimetable?KEY=$apiKey&Type=json&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&GRADE=${grade.toString()}&CLASS_NM=${classNum.toString()}&TI_FROM_YMD=${formatter.format(thisWeekStart)}&TI_TO_YMD=${formatter.format(thisWeekEnd)}',
          );
          final thisWeekResponse = await http.get(thisWeekUrl);
          if (thisWeekResponse.statusCode == 200) {
            final data = json.decode(thisWeekResponse.body);
            if (data['hisTimetable'] != null) {
              // 캐시는 ApiService의 인터셉터가 처리하므로 여기서는 별도로 저장하지 않음
              print('이번주 시간표 프리로딩 완료');
            }
          }
        } catch (e) {
          print('이번주 시간표 프리로딩 실패: $e');
        }

        // 다음주 시간표 프리로딩
        try {
          final nextWeekUrl = Uri.parse(
            'https://open.neis.go.kr/hub/hisTimetable?KEY=$apiKey&Type=json&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&GRADE=${grade.toString()}&CLASS_NM=${classNum.toString()}&TI_FROM_YMD=${formatter.format(nextWeekStart)}&TI_TO_YMD=${formatter.format(nextWeekEnd)}',
          );
          final nextWeekResponse = await http.get(nextWeekUrl);
          if (nextWeekResponse.statusCode == 200) {
            final data = json.decode(nextWeekResponse.body);
            if (data['hisTimetable'] != null) {
              print('다음주 시간표 프리로딩 완료');
            }
          }
        } catch (e) {
          print('다음주 시간표 프리로딩 실패: $e');
        }
      } catch (e) {
        print('시간표 프리로딩 실패: $e');
      }
    });
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
                Center(
                  child: Text(
                    widget.existingUserInfo != null ? '인적사항 수정' : '환영합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
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
                              widget.existingUserInfo != null ? '수정 완료' : '설정 완료',
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
