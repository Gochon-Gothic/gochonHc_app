import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../utils/responsive_helper.dart';

class LunchScreen extends StatefulWidget {
  const LunchScreen({super.key});

  @override
  State<LunchScreen> createState() => _LunchScreenState();
}

class _LunchScreenState extends State<LunchScreen> {
  String? menu;
  bool isLoading = true;
  String? error;
  DateTime currentDate = DateTime.now();

  static const String apiKey = '44e1ba05c56746c5a09a5fbd5eead0be';
  static const String eduOfficeCode = 'J10';
  static const String schoolCode = '7531375';

  Map<int, String> allergyMap = {
    1: '난류',
    2: '우유',
    3: '메밀',
    4: '땅콩',
    5: '대두',
    6: '밀',
    7: '고등어',
    8: '게',
    9: '새우',
    10: '돼지고기',
    11: '복숭아',
    12: '토마토',
    13: '아황산류',
    14: '호두',
    15: '닭고기',
    16: '쇠고기',
    17: '오징어',
    18: '조개류(굴, 전복, 홍합 포함)',
    19: '잣',
  };

  Set<int> allergySet = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko', null).then((_) {
      setState(() {
        currentDate = _skipWeekend(currentDate, forward: false);
      });
      fetchMeal();
    });
  }

  DateTime _skipWeekend(DateTime date, {required bool forward}) {
    while (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      date = date.add(Duration(days: forward ? 1 : -1));
    }
    return date;
  }

  String _buildApiUrl(String date) {
    return 'https://open.neis.go.kr/hub/mealServiceDietInfo?KEY=$apiKey&Type=json&pIndex=1&pSize=1&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&MLSV_YMD=$date';
  }

  Future<void> _saveCache(SharedPreferences prefs, String cacheKey, String responseBody) async {
    await prefs.setString(cacheKey, responseBody);
    await prefs.setInt(
      '${cacheKey}_lastUpdate',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> fetchMeal() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
      allergySet.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyyMMdd').format(currentDate);
      final cacheKey = 'lunch_$today';
      final cachedData = prefs.getString(cacheKey);
      final lastUpdate = prefs.getInt('${cacheKey}_lastUpdate') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheExpiry = 259200000;

      if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
        try {
          final data = json.decode(cachedData);
          _parseMealData(data);
          _setStateSafe(() {
            isLoading = false;
          });
          _updateMealInBackground(prefs, cacheKey, today);
          return;
        } catch (e) {
          // 캐시 파싱 실패 시 API에서 다시 가져오기
        }
      }

      await _fetchMealFromAPI(prefs, cacheKey, today);
    } catch (e) {
      _setStateSafe(() {
        error = '급식을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchMealFromAPI(
    SharedPreferences prefs,
    String cacheKey,
    String today,
  ) async {
    try {
      final url = _buildApiUrl(today);
      print('급식 API 호출 시도: $url');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('API 호출 시간 초과');
        },
      );
      print('급식 API 응답 상태 코드: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('급식 API 호출 실패: 상태 코드 ${response.statusCode}, 응답: ${response.body}');
        _setStateSafe(() {
          error = '급식을 불러오는데 실패했습니다.';
          isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body);
      await _saveCache(prefs, cacheKey, response.body);
      _parseMealData(data);
      _setStateSafe(() {
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('급식 API 호출 에러: $e');
      print('에러 타입: ${e.runtimeType}');
      print('스택 트레이스: $stackTrace');
      _setStateSafe(() {
        error = '급식을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  Future<void> _updateMealInBackground(
    SharedPreferences prefs,
    String cacheKey,
    String today,
  ) async {
    try {
      final url = _buildApiUrl(today);
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['mealServiceDietInfo'] != null) {
          await _saveCache(prefs, cacheKey, response.body);
          _setStateSafe(() {
            _parseMealData(data);
          });
        }
      }
    } catch (e) {
      // 백그라운드 업데이트 실패는 무시
    }
  }

  String _cleanMenuName(String menuName) {
    menuName = menuName.replaceAll(RegExp(r'\([\d.]+\)'), '');
    menuName = menuName.replaceAll(RegExp(r'\*+\d*'), '');
    menuName = menuName.replaceAll(RegExp(r'\d+$'), '');
    
    String cleaned = '';
    bool inParentheses = false;
    String parenthesesContent = '';
    
    for (int i = 0; i < menuName.length; i++) {
      final char = menuName[i];
      
      if (char == '(') {
        inParentheses = true;
        parenthesesContent = '';
        cleaned += char;
      } else if (char == ')') {
        if (inParentheses) {
          if (RegExp(r'^[\uAC00-\uD7A3\s]*$').hasMatch(parenthesesContent)) {
            cleaned += parenthesesContent + char;
          }
          inParentheses = false;
          parenthesesContent = '';
        }
      } else if (inParentheses) {
        parenthesesContent += char;
      } else {
        if (RegExp(r'[\uAC00-\uD7A3\s]').hasMatch(char)) {
          cleaned += char;
        }
      }
    }
    
    return cleaned.trim();
  }

  void _parseMealData(Map<String, dynamic> data) {
    if (data['mealServiceDietInfo'] != null) {
      final row = data['mealServiceDietInfo'][1]['row'][0];
      String rawMenu = row['DDISH_NM'];

      final allergyReg = RegExp(r'\((\d+(?:\.\d+)*)\)');
      final matches = allergyReg.allMatches(rawMenu);
      for (final match in matches) {
        final nums = match
            .group(1)!
            .split('.')
            .map((e) => int.tryParse(e))
            .whereType<int>();
        allergySet.addAll(nums);
      }

      String cleaned = rawMenu
          .replaceAll(RegExp(r'＃ ?\([\d.]+\)'), '')
          .replaceAll('<br/>', '\n')
          .replaceAll('<br />', '\n')
          .replaceAll('＃', '')
          .replaceAll('\n\n', '\n')
          .trim();

      final menuLines = cleaned.split('\n');
      final cleanMenuLines = menuLines
          .map((line) => _cleanMenuName(line))
          .where((line) => line.isNotEmpty)
          .toList();

      final cleanMenu = cleanMenuLines.join('\n').trim();

      _setStateSafe(() {
        menu = cleanMenu;
      });
    } else {
      _setStateSafe(() {
        error = '급식 정보가 존재하지 않습니다';
      });
    }
  }

  void _changeDate(int diff) {
    DateTime newDate = currentDate.add(Duration(days: diff));
    newDate = _skipWeekend(newDate, forward: diff > 0);
    _setStateSafe(() {
      currentDate = newDate;
    });
    fetchMeal();
  }

  Widget _buildAllergyCard(Color cardColor, Color textColor, bool isDark) {
    final allergyList = (allergySet.toList()..sort())
        .map((n) => allergyMap[n])
        .whereType<String>()
        .join(', ');

    return Card(
      margin: ResponsiveHelper.padding(context, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: ResponsiveHelper.borderRadius(context, 12),
      ),
      elevation: 2,
      color: cardColor,
      child: Container(
        width: double.infinity,
        padding: ResponsiveHelper.padding(context, all: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isDark ? textColor : Colors.red,
            ),
            ResponsiveHelper.horizontalSpace(context, 8),
            Expanded(
              child: Text(
                '알레르기 정보: $allergyList',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final todayStr = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(currentDate);
    final todayStrShort = DateFormat('M월 d일', 'ko').format(currentDate);
    return Container(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveHelper.verticalSpace(context, 80),
          Padding(
            padding: ResponsiveHelper.horizontalPadding(context, 24),
            child: Row(
              children: [
                Text(
                  '오늘의 급식',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: ResponsiveHelper.width(context, 60),
                  height: ResponsiveHelper.height(context, 60),
                  child: SvgPicture.asset(
                    'assets/images/gochon_logo.svg',
                    semanticsLabel: 'Gochon Logo',
                  ),
                ),
              ],
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 5),
          Padding(
            padding: ResponsiveHelper.padding(
              context,
              horizontal: 24,
              vertical: 8,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_left,
                    size: ResponsiveHelper.width(context, 32),
                  ),
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      todayStr,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 20,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_right,
                    size: ResponsiveHelper.width(context, 32),
                  ),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Container(
                      margin: ResponsiveHelper.padding(
                        context,
                        top: 40,
                        bottom: 180,
                      ),
                      padding: ResponsiveHelper.horizontalPadding(context, 24),
                      child: Center(
                        child: Text(
                          error!,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 20,
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Card(
                          margin: ResponsiveHelper.padding(
                            context,
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: ResponsiveHelper.borderRadius(context, 12),
                          ),
                          elevation: 2,
                          color: cardColor,
                          child: Container(
                            width: double.infinity,
                            padding: ResponsiveHelper.padding(context, all: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$todayStrShort 급식',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                ResponsiveHelper.verticalSpace(context, 9),
                                Text(
                                  menu ?? '',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 19,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (allergySet.isNotEmpty)
                          _buildAllergyCard(cardColor, textColor, isDark),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
