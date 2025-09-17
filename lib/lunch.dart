import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'theme_colors.dart';

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

  // 여기에 본인 인증키 입력
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

  // 급식 혼잡도 변수들
  Map<int, Map<String, dynamic>> congestionMap = {
    1: {'status': '급식줄 현재 여유', 'color': const Color.fromARGB(255, 68, 168, 71)},
    2: {'status': '급식줄 보통', 'color': const Color.fromARGB(255, 225, 170, 3)},
    3: {'status': '급식줄 혼잡함', 'color': const Color.fromARGB(255, 237, 64, 64)},
  };

  int congestionLevel = 1; // 기본값

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

      // 캐시가 있고 만료되지 않았으면 캐시 사용
      if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
        try {
          final data = json.decode(cachedData);
          _parseMealData(data);
          if (!mounted) return;
          setState(() {
            isLoading = false;
          });

          // 백그라운드에서 새 데이터 업데이트
          _updateMealInBackground(prefs, cacheKey, today);
          return;
        } catch (e) {
          // 캐시 파싱 실패 시 무시하고 API 호출
        }
      }

      // API 호출
      await _fetchMealFromAPI(prefs, cacheKey, today);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '급식을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  // API에서 급식 데이터 가져오기
  Future<void> _fetchMealFromAPI(
    SharedPreferences prefs,
    String cacheKey,
    String today,
  ) async {
    try {
      final url =
          'https://open.neis.go.kr/hub/mealServiceDietInfo?KEY=$apiKey&Type=json&pIndex=1&pSize=1&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&MLSV_YMD=$today';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          error = '급식을 불러오는데 실패했습니다.';
          isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body);

      // 성공 시 캐시에 저장
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt(
        '${cacheKey}_lastUpdate',
        DateTime.now().millisecondsSinceEpoch,
      );

      _parseMealData(data);
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '급식을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  // 백그라운드에서 급식 업데이트
  Future<void> _updateMealInBackground(
    SharedPreferences prefs,
    String cacheKey,
    String today,
  ) async {
    try {
      final url =
          'https://open.neis.go.kr/hub/mealServiceDietInfo?KEY=$apiKey&Type=json&pIndex=1&pSize=1&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&MLSV_YMD=$today';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['mealServiceDietInfo'] != null) {
          // 백그라운드에서 캐시 업데이트
          await prefs.setString(cacheKey, response.body);
          await prefs.setInt(
            '${cacheKey}_lastUpdate',
            DateTime.now().millisecondsSinceEpoch,
          );

          // UI 업데이트
          if (mounted) {
            _parseMealData(data);
            setState(() {});
          }
        }
      }
    } catch (e) {
      // 백그라운드 업데이트 실패는 무시
    }
  }

  // 급식 데이터 파싱
  void _parseMealData(Map<String, dynamic> data) {
    if (data['mealServiceDietInfo'] != null) {
      final row = data['mealServiceDietInfo'][1]['row'][0];
      String rawMenu = row['DDISH_NM'];

      // 알레르기 번호 추출
      final allergyReg = RegExp(r'\((\d+(?:\.\d+)*)\)');
      final matches = allergyReg.allMatches(rawMenu);
      for (final match in matches) {
        final nums =
            match
                .group(1)!
                .split('.')
                .map((e) => int.tryParse(e))
                .whereType<int>();
        allergySet.addAll(nums);
      }

      // 메뉴에서 (번호...)와 # (번호...) 모두 제거
      String cleanMenu =
          rawMenu
              .replaceAll(RegExp(r'＃ ?\([\d.]+\)'), '')
              .replaceAll(RegExp(r'\([\d.]+\)'), '')
              .replaceAll('<br/>', '\n')
              .replaceAll('＃', '')
              .replaceAll('\n\n', '\n')
              .trim();

      if (mounted) {
        setState(() {
          menu = cleanMenu;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          error = '오늘은 급식이 제공되지 않습니다.';
        });
      }
    }
  }

  void _changeDate(int diff) {
    DateTime newDate = currentDate.add(Duration(days: diff));
    newDate = _skipWeekend(newDate, forward: diff > 0);
    setState(() {
      currentDate = newDate;
    });
    fetchMeal();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final todayStr = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(currentDate);
    final todayStr2 = DateFormat('M월 d일', 'ko').format(currentDate);
    return Container(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '오늘의 급식',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: textColor,

              ),
            ),
          ),
          const SizedBox(height: 5),
          // 밑줄
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Container(width: 190, height: 3, color: textColor),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left, size: 32),
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      todayStr,
                      style: TextStyle(
                        fontSize: 20,
                        color: textColor,
        
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right, size: 32),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),
          // 급식 혼잡도 표시기 (날짜 행 바로 아래)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            color: congestionMap[congestionLevel]!['color'],
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  congestionMap[congestionLevel]!['status'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Container(
                      margin: const EdgeInsets.only(top: 40, bottom: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
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
                          margin: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          color: cardColor,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$todayStr2 급식',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  menu ?? '',
                                  style: TextStyle(
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
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            color: cardColor,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: isDark ? textColor : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '알레르기 정보: ${(allergySet.toList()..sort()).map((n) => allergyMap[n]).whereType<String>().join(', ')}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
