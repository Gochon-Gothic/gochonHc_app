import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme_provider.dart';
import 'theme_colors.dart';


class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<List<String>> timetable = List.generate(5, (_) => List.filled(7, ''));
  bool isLoading = true;
  String? error;
  String selectedGrade = '1';
  String selectedClass = '1';
  DateTime currentWeekStart = DateTime.now().toUtc().add(
    const Duration(hours: 9),
  );
  bool isNextWeek = false;
  bool _isTableView = true; // true: 표, false: 리스트
  int? _selectedListDayIndex; // 리스트 모드에서 선택된 요일(0:월~4:금)
  final Map<String, String> _shortenCache = {}; // 과목 축약 캐시
  final PageController _dayController = PageController();

  // 현재 날짜에 따라 적절한 주의 시작일 계산
  DateTime getCurrentWeekStart() {
    // 한국 시간대(KST, UTC+9)로 현재 시간 가져오기
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final weekday = now.weekday;

    // 토요일(6) 또는 일요일(7)이면 다음주 월요일부터
    if (weekday >= 6) {
      return now.add(Duration(days: 8 - weekday));
    } else {
      // 평일이면 해당 주의 월요일부터
      return now.subtract(Duration(days: weekday - 1));
    }
  }

  // 학년/반은 API 요청에만 사용. 최대 반/학년 정보는 사용하지 않음(레이아웃 단순화)

  @override
  void initState() {
    super.initState();
    currentWeekStart = getCurrentWeekStart();
    _initMyClassAndLoad();
    // 리스트 모드 기본 선택 요일: 오늘(월~금) 아니면 월요일
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final todayIdx = now.weekday - 1;
    _selectedListDayIndex = (todayIdx >= 0 && todayIdx < 5) ? todayIdx : 0;
    
    // PageController 리스너 추가 (캡슐 애니메이션을 위해)
    _dayController.addListener(_onPageControllerChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayController.hasClients) {
        _dayController.jumpToPage(_selectedListDayIndex ?? 0);
      }
    });
  }

  Future<void> _initMyClassAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    if (userEmail != null) {
      final gradeClass = userEmail.split('@')[0].split('-')[1];
      String grade = gradeClass[0];
      String ban =
          (gradeClass.length > 2 && gradeClass[1] == '0')
              ? gradeClass[2]
              : gradeClass.substring(1, 3);
      if (mounted) {
        setState(() {
          selectedGrade = grade;
          selectedClass = ban;
        });
      }
    }
    loadTimetable();
  }

  // 요일별 교시 수 반환
  int getPeriodCount(int dayIndex) {
    switch (dayIndex) {
      case 0: // 월
      case 4: // 금
        return 7;
      default: // 화, 수, 목
        return 6;
    }
  }

  // 교과시간 관련 로직 제거됨

  // 날짜 범위 문자열 생성
  String getDateRange() {
    final weekStart = currentWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 4)); // 금요일까지

    final formatter = DateFormat('yyyyMMdd');
    return '${formatter.format(weekStart)}:${formatter.format(weekEnd)}';
  }

  // 주간 날짜(일~토) 계산. currentWeekStart(월) 기준으로 반환
  List<DateTime> getWeekDates() {
    final monday = currentWeekStart;
    final sunday = monday.subtract(const Duration(days: 1));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  // 주 이동 유틸(미사용)

  void _toggleView() {
    setState(() {
      _isTableView = !_isTableView;
    });
  }

  void _onPageControllerChanged() {
    if (_dayController.hasClients && mounted) {
      setState(() {
        // 페이지 변경시 UI 업데이트 (캡슐 위치 변경)
      });
    }
  }

  Future<void> loadTimetable() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');
      if (userEmail == null) {
        if (!mounted) return;
        setState(() {
          error = '로그인이 필요합니다.';
          isLoading = false;
        });
        return;
      }

      // 캐시 키 생성 (학년/반/날짜범위로 고유 키 생성)
      final cacheKey =
          'timetable_${selectedGrade}_${selectedClass}_${getDateRange()}';
      final cachedData = prefs.getString(cacheKey);
      final lastUpdate = prefs.getInt('${cacheKey}_lastUpdate') ?? 0;
      final now =
          DateTime.now()
              .toUtc()
              .add(const Duration(hours: 9))
              .millisecondsSinceEpoch;
      final cacheExpiry = 7200000; // 2시간 만료 (시간표는 갑작스러운 변경 가능성)

      // 캐시가 있고 만료되지 않았으면 캐시 사용
      if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
        try {
          final data = json.decode(cachedData);
          if (data['hisTimetable'] != null) {
            final timetableData = data['hisTimetable'][1]['row'] as List;
            parseAndSetTimetable(timetableData);
            if (!mounted) return;
            setState(() {
              isLoading = false;
            });

            // 백그라운드에서 새 데이터 업데이트 (사용자 체감 개선)
            updateTimetableInBackground();
            return;
          }
        } catch (e) {}
      }

      // API 호출
      await fetchTimetableFromAPI(prefs, cacheKey);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  // API에서 시간표 데이터 가져오기
  Future<void> fetchTimetableFromAPI(
    SharedPreferences prefs,
    String cacheKey,
  ) async {
    try {
      // API 키와 학교 정보
      const apiKey = '2cf24c119b434f93b2f916280097454a';
      const eduOfficeCode = 'J10';
      const schoolCode = '7531375';

      final dateRange = getDateRange();
      final url = Uri.parse(
        'https://open.neis.go.kr/hub/hisTimetable?KEY=$apiKey&Type=json&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&GRADE=$selectedGrade&CLASS_NM=$selectedClass&TI_FROM_YMD=${dateRange.split(':')[0]}&TI_TO_YMD=${dateRange.split(':')[1]}',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          error = '시간표를 불러오는데 실패했습니다.';
          isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body);
      if (data['hisTimetable'] == null) {
        if (!mounted) return;
        setState(() {
          error = '시간표 데이터가 없습니다.';
          isLoading = false;
        });
        return;
      }

      // 성공 시 캐시에 저장
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt(
        '${cacheKey}_lastUpdate',
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 9))
            .millisecondsSinceEpoch,
      );

      final timetableData = data['hisTimetable'][1]['row'] as List;
      parseAndSetTimetable(timetableData);

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      // API 호출 실패 시 캐시 fallback
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final data = json.decode(cachedData);
          if (data['hisTimetable'] != null) {
            final timetableData = data['hisTimetable'][1]['row'] as List;
            parseAndSetTimetable(timetableData);
            if (!mounted) return;
            setState(() {
              error = '네트워크 오류가 발생했습니다.';
              isLoading = false;
            });
            return;
          }
        } catch (e) {
          // 캐시 fallback도 실패
        }
      }

      if (!mounted) return;
      setState(() {
        error = '시간표를 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  // 백그라운드에서 시간표 업데이트 (사용자 체감 개선)
  Future<void> updateTimetableInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey =
          'timetable_${selectedGrade}_${selectedClass}_${getDateRange()}';

      const apiKey = '2cf24c119b434f93b2f916280097454a';
      const eduOfficeCode = 'J10';
      const schoolCode = '7531375';

      final dateRange = getDateRange();
      final url = Uri.parse(
        'https://open.neis.go.kr/hub/hisTimetable?KEY=$apiKey&Type=json&ATPT_OFCDC_SC_CODE=$eduOfficeCode&SD_SCHUL_CODE=$schoolCode&GRADE=$selectedGrade&CLASS_NM=$selectedClass&TI_FROM_YMD=${dateRange.split(':')[0]}&TI_TO_YMD=${dateRange.split(':')[1]}',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hisTimetable'] != null) {
          // 백그라운드에서 캐시 업데이트
          await prefs.setString(cacheKey, response.body);
          await prefs.setInt(
            '${cacheKey}_lastUpdate',
            DateTime.now()
                .toUtc()
                .add(const Duration(hours: 9))
                .millisecondsSinceEpoch,
          );

          // UI 업데이트 (사용자에게 알림)
          if (mounted) {
            final timetableData = data['hisTimetable'][1]['row'] as List;
            parseAndSetTimetable(timetableData);
            setState(() {}); // UI 새로고침
          }
        }
      }
    } catch (e) {
      // 백그라운드 업데이트 실패는 무시 (사용자에게 영향 없음)
      // 백그라운드 업데이트 실패는 무시
    }
  }

  // 시간표 데이터 파싱 및 설정 (코드 재사용성 향상)
  void parseAndSetTimetable(List<dynamic> timetableData) {
    // 시간표 데이터 파싱
    final newTimetable = List.generate(5, (dayIndex) => List.filled(7, ''));
    // 날짜별로 모의고사 여부 체크를 위한 Map
    final Map<String, bool> isMockExamDay = {};

    for (var item in timetableData) {
      final date = item['ALL_TI_YMD'].toString();
      final day = DateTime.parse(date).weekday - 1; // 0: 월요일
      // 모의고사 체크
      if (item['ITRT_CNTNT'].toString().contains('전국연합')) {
        isMockExamDay[date] = true;
      }
      if (day >= 0 && day < 5) {
        final period = int.parse(item['PERIO']) - 1;
        if (period >= 0 && period < 7) {
          newTimetable[day][period] = item['ITRT_CNTNT'];
        }
      }
    }

    // 모의고사 날짜의 모든 과목을 '모고'로 변경
    for (var item in timetableData) {
      final date = item['ALL_TI_YMD'].toString();
      if (isMockExamDay[date] == true) {
        final day = DateTime.parse(date).weekday - 1;
        if (day >= 0 && day < 5) {
          final period = int.parse(item['PERIO']) - 1;
          if (period >= 0 && period < 7) {
            newTimetable[day][period] = '모고';
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        timetable = newTimetable;
      });
    }
  }

  var dayoff = [
    '현충일',
    '대체공휴일',
    '신정',
    '설날',
    '어린이',
    '광복절',
    '개천절',
    '성탄절',
    '삼일절',
    '부처님',
    '추석',
    '한글날',
    '기독탄신일',
    '학교장',
  ];

  String shortenSubject(String subject) {
    if (_shortenCache.containsKey(subject)) return _shortenCache[subject]!;
    // 휴일 체크
    for (var holiday in dayoff) {
      if (subject.contains(holiday)) return '휴일';
    }

    //과탐
    if (subject.contains('지구과학Ⅰ')) return '지구Ⅰ';
    if (subject.contains('지구과학Ⅱ')) return '지구ⅠⅠ';
    if (subject.contains('물리학Ⅰ')) return '물리Ⅰ';
    if (subject.contains('물리학Ⅱ')) return '물리ⅠⅠ';
    if (subject.contains('화학Ⅰ')) return '화학Ⅰ';
    if (subject.contains('화학Ⅱ')) return '화학ⅠⅠ';
    if (subject.contains('생명과학Ⅰ')) return '생명Ⅰ';
    if (subject.contains('생명과학Ⅱ')) return '생명ⅠⅠ';
    //사탐
    if (subject.contains('여행지리')) return '여지';
    if (subject.contains('데이터')) return '머신';
    if (subject.contains('심화 국어')) return '심국';
    if (subject.contains('사회·문화')) return '사문';
    if (subject.contains('세계시민')) return '시민';
    if (subject.contains('실용 경제')) return '실경';
    if (subject.contains('동아시아사')) return '동사';
    if (subject.contains('사회문제 탐구')) return '사탐';
    if (subject.contains('생활과 윤리')) return '생윤';
    if (subject.contains('한국지리')) return '한지';
    if (subject.contains('공통영어')) return '영어';
    if (subject.contains('세계지리')) return '세지';
    if (subject.contains('정치와 법')) return '정법';
    if (subject.contains('스포츠 생활')) return '스생';
    if (subject.contains('체육 전공 실기 기초')) return '체전';
    if (subject.contains('진로활동')) return '진로';
    if (subject.contains('프로그래밍')) return '프로';
    if (subject.contains('윤리와 사상')) return '윤사';
    if (subject.contains('통합과학')) return '통과';
    if (subject.contains('통합사회')) return '통사';
    if (subject.contains('공통수학')) return '수학';
    if (subject.contains('공통국어')) return '국어';
    if (subject.contains('과학탐구실험')) return '과탐실';
    if (subject.contains('영어권 문화')) return '영문';
    if (subject.contains('한국지리')) return '한지';
    if (subject.contains('고전 읽기')) return '고전';
    if (subject.contains('화법과 작문')) return '화작';
    if (subject.contains('확률과 통계')) return '확통';
    if (subject.contains('언어와 매체')) return '언매';
    if (subject.contains('영어 독해와 작문')) return '영독';
    if (subject.contains('심화 국어')) return '국어';
    if (subject.contains('사회문화')) return '사문';
    if (subject.contains('운동과 건강')) return '운건';
    if (subject.contains('생활과 과학')) return '생과';
    if (subject.contains('미술 창작')) return '미창';
    if (subject.contains('음악 연주')) return '음연';
    if (subject.contains('미술 전공 실기')) return '미전';
    if (subject.contains('음악 전공')) return '음전';
    if (subject.contains('체육전공 실기')) return '체전';
    if (subject.contains('전국연합')) return '모고';
    if (subject.contains('자율')) return '창체';
    if (subject.contains('한국사')) return '한국사';

    // 기타: 2글자 이하, 3글자 이하 등 자동 축약
    String result;
    if (subject.length > 4) {
      result = subject.substring(0, 2);
    } else if (subject.length > 2) {
      result = subject.substring(0, 3);
    } else {
      result = subject;
    }
    _shortenCache[subject] = result;
    return result;
  }

  // 캐시 삭제 함수
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // 시간표 관련 캐시만 삭제
      for (final key in keys) {
        if (key.startsWith('timetable_')) {
          await prefs.remove(key);
        }
      }

      if (mounted) {
        setState(() {
          // 캐시 삭제 후 새로 로드
          loadTimetable();
        });
      }
    } catch (e) {
      // 캐시 삭제 실패 무시
    }
  }

  @override
  void dispose() {
    _dayController.removeListener(_onPageControllerChanged);
    _dayController.dispose();
    super.dispose();
  }

  // 캐시 상태 확인
  Future<String> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey =
          'timetable_${selectedGrade}_${selectedClass}_${getDateRange()}';
      final cachedData = prefs.getString(cacheKey);
      final lastUpdate = prefs.getInt('${cacheKey}_lastUpdate') ?? 0;

      if (cachedData == null) {
        return '캐시 없음';
      }

      final now =
          DateTime.now()
              .toUtc()
              .add(const Duration(hours: 9))
              .millisecondsSinceEpoch;
      final timeDiff = now - lastUpdate;

      if (timeDiff < 3600000) {
        // 1시간
        return '최근 업데이트됨 (${(timeDiff / 60000).round()}분 전)';
      } else if (timeDiff < 86400000) {
        // 1일
        return '오늘 업데이트됨';
      } else {
        return '오래된 캐시 (${(timeDiff / 86400000).round()}일 전)';
      }
    } catch (e) {
      return '캐시 상태 확인 실패';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    if (error != null) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: textColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                error!,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    error = null;
                    isLoading = true;
                  });
                  loadTimetable();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          const SizedBox(height: 60),
          // 상단 타이틀 + 로고
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 시간표',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 39,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat('MM/dd').format(currentWeekStart)}~${DateFormat('MM/dd').format(currentWeekStart.add(const Duration(days: 4)))}',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: SvgPicture.asset(
                    'assets/images/gochon_logo.svg',
                    semanticsLabel: 'Gochon Logo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 주간(일~토) 헤더: 표 모드에서는 숨김, 리스트 모드에서만 표시
          if (!_isTableView)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 90,
                child: _WeekHeader(
                  controller: _dayController,
                  dates: getWeekDates(),
                  textColor: textColor,
                  selectedIndex: (_selectedListDayIndex ?? ((DateTime.now().toUtc().add(const Duration(hours: 9)).weekday - 1).clamp(0, 4))) + 1,
                  isDark: isDark,
                  onTapDay: (dowIndex) {
                    final idx = dowIndex - 1; // 월=0
                    if (idx >= 0 && idx < 5) {
                      setState(() => _selectedListDayIndex = idx);
                      if (_dayController.hasClients) {
                        _dayController.animateToPage(
                          idx, 
                          duration: const Duration(milliseconds: 350), 
                          curve: Curves.easeInOutCubic
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          // 토글(우측 정렬)
          Padding(
            padding: const EdgeInsets.only(right: 24, top: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _toggleView,
                child: Text(
                  _isTableView ? '리스트로 보기' : '표로 보기',
                  style: TextStyle(
                    color: const Color(0xFF999999),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(offset: const Offset(2, 3), blurRadius: 3, color: Colors.black.withValues(alpha: 0.20)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 본문: 표 / 리스트
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isTableView
                ? _buildTableView(isDark, textColor)
                : _buildListView(cardColor, textColor, isDark),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  // 표 보기
  Widget _buildTableView(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 헤더 행: 요일 (동등 폭, 네 외곽만 라운드)
          LayoutBuilder(builder: (context, constraints) {
            const double gap = 8;
            final double itemWidth = (constraints.maxWidth - gap * 4) / 5;
            return Row(
              children: List.generate(5, (i) {
                final bool topLeft = i == 0;
                final bool topRight = i == 4;
                return Container(
                  width: itemWidth,
                  height: 36,
                  margin: EdgeInsets.only(right: i == 4 ? 0 : gap),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: CustomPaint(
                    painter: _CornerPainter(
                      fill: isDark ? const Color(0xFF1E1E1E) : const Color.fromARGB(255, 203, 204, 208),
                      radius: 12,
                      topLeft: topLeft,
                      topRight: topRight,
                      bottomLeft: false,
                      bottomRight: false,
                    ),
                    child: Center(
                      child: Text(
                        const ['월', '화', '수', '목', '금'][i],
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : const Color(0xFF30302E),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 8),
          ...List.generate(7, (row) {
            return LayoutBuilder(builder: (context, constraints) {
              const double gap = 8;
              final double itemWidth = (constraints.maxWidth - gap * 4) / 5;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: List.generate(5, (dayIdx) {
                    final int lastIndex = getPeriodCount(dayIdx) - 1; // 0-based
                    if (row == 6 && lastIndex == 5) {
                      return SizedBox(width: itemWidth + (dayIdx == 4 ? 0 : gap));
                    }
                    String cell = '';
                    if (dayIdx < timetable.length && row < timetable[dayIdx].length) {
                      cell = timetable[dayIdx][row];
                    }
                    final bool bottomLeft = dayIdx == 0 && row == lastIndex;
                    final bool bottomRight = dayIdx == 4 && row == lastIndex;
                    return Container(
                      width: itemWidth,
                      height: 50,
                      margin: EdgeInsets.only(right: dayIdx == 4 ? 0 : gap),
                      decoration: const BoxDecoration(color: Colors.transparent),
                      child: CustomPaint(
                        painter: _CornerPainter(
                          fill: isDark ? const Color(0xFF1E1E1E) : const Color.fromARGB(255, 203, 204, 208),
                          radius: 12,
                          topLeft: false,
                          topRight: false,
                          bottomLeft: bottomLeft,
                          bottomRight: bottomRight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              shortenSubject(cell),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? AppColors.darkText : const Color(0xFF30302E),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            });
          }),
        ],
      ),
    );
  }
  Widget _buildListView(Color cardColor, Color textColor, bool isDark) {
    return SizedBox(
      height: 500, // 적절한 고정 높이 설정
      child: PageView.builder(
        controller: _dayController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedListDayIndex = index;
          });
        },
        itemCount: 5, // 월~금
        itemBuilder: (context, dayIdx) {
          final List<_PeriodInfo> periods = _buildPeriodInfos(dayIdx);
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ...List.generate(periods.length, (i) {
                  final info = periods[i];
                  final subject = (dayIdx < timetable.length && info.periodIndex < timetable[dayIdx].length)
                      ? timetable[dayIdx][info.periodIndex]
                      : '';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: CustomPaint(
                      painter: _OuterCornersPainter(
                        fill: cardColor,
                        radius: 20,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${info.label} | ${_formatAmPm(info.start)} ${_formatAmPm(info.end)}',
                              style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w400, height: 1.28),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subject.isEmpty ? '-' : subject,
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600, height: 1.28),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 80), // 하단 여백 추가
              ],
            ),
          );
        },
      ),
    );
  }

  List<_PeriodInfo> _buildPeriodInfos(int dayIdx) {
    // 월/금 7교시, 화/수/목 6교시
    final count = getPeriodCount(dayIdx);
    final base = [
      _PeriodInfo(periodIndex: 0, label: '1교시', start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 9, minute: 50)),
      _PeriodInfo(periodIndex: 1, label: '2교시', start: const TimeOfDay(hour: 10, minute: 0), end: const TimeOfDay(hour: 10, minute: 50)),
      _PeriodInfo(periodIndex: 2, label: '3교시', start: const TimeOfDay(hour: 11, minute: 0), end: const TimeOfDay(hour: 11, minute: 50)),
      _PeriodInfo(periodIndex: 3, label: '4교시', start: const TimeOfDay(hour: 12, minute: 0), end: const TimeOfDay(hour: 12, minute: 50)),
      _PeriodInfo(periodIndex: 4, label: '5교시', start: const TimeOfDay(hour: 14, minute: 0), end: const TimeOfDay(hour: 14, minute: 50)),
      _PeriodInfo(periodIndex: 5, label: '6교시', start: const TimeOfDay(hour: 15, minute: 0), end: const TimeOfDay(hour: 15, minute: 50)),
      _PeriodInfo(periodIndex: 6, label: '7교시', start: const TimeOfDay(hour: 16, minute: 0), end: const TimeOfDay(hour: 16, minute: 50)),
    ];
    return base.take(count).toList(growable: false);
  }

  String _formatAmPm(TimeOfDay t) {
    final int hour12 = (t.hour % 12 == 0) ? 12 : (t.hour % 12);
    final String ampm = t.hour < 12 ? 'AM' : 'PM';
    final String mm = t.minute.toString().padLeft(2, '0');
    return '$hour12:$mm $ampm';
  }
}

class _WeekHeader extends StatelessWidget {
  final PageController? controller;
  final List<DateTime> dates; // 일~토
  final Color textColor;
  final ValueChanged<int>? onTapDay; // 0:일 ~ 6:토
  final int? selectedIndex; // 0~6 (이미지처럼 선택 요일 하이라이트)
  final bool isDark;

  const _WeekHeader({this.controller, required this.dates, required this.textColor, this.onTapDay, this.selectedIndex, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final labels = const ['일', '월', '화', '수', '목', '금', '토'];
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Stack(
            children: [
              // 요일 텍스트 + 터치버튼(요일+날짜 전체가 버튼)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double gap = 8;
                    final double itemWidth = (constraints.maxWidth - gap * 6) / 7;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Row(
                        children: List.generate(7, (i) {
                          Color c = textColor;
                          if (i == 0) c = const Color.fromRGBO(236, 69, 69, 1);
                          if (i == 6) c = const Color.fromARGB(255, 203, 204, 208);
                          final d = dates[i];
                          
                          return GestureDetector(
                            onTap: () => onTapDay?.call(i),
                            child: Container(
                              width: itemWidth,
                              margin: EdgeInsets.only(right: i == 6 ? 0 : gap),
                              child: Stack(
                                children: [
                                  if (selectedIndex == i && i >= 1 && i <= 5)
                                    AnimatedBuilder(
                                      animation: controller ?? const AlwaysStoppedAnimation(0.0),
                                      builder: (context, _) {
                                        double page = (selectedIndex! - 1).toDouble().clamp(0, 4);
                                        if (controller?.positions.isNotEmpty == true) {
                                          final p = controller?.page;
                                          if (p != null) {
                                            page = p.clamp(0, 4);
                                          }
                                        }
                                        
                                        // 현재 요일과 스크롤 페이지 차이로 투명도 계산
                                        final double currentDayIndex = (i - 1).toDouble().clamp(0, 4);
                                        final double opacity = 1.0 - (page - currentDayIndex).abs().clamp(0.0, 1.0);
                                        
                                        return Positioned.fill(
                                          child: Opacity(
                                            opacity: opacity,
                                            child: Container(
                                              transform: Matrix4.translationValues(-17.13, 0, 0),
                                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12), // 왼쪽 정렬 보정
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isDark 
                                                        ? const Color.fromRGBO(255, 255, 255, 0.12) 
                                                        : const Color.fromRGBO(0, 0, 0, 0.08),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: const Color.fromRGBO(255, 255, 255, 0.35), 
                                                      width: 1
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  // 요일과 날짜 텍스트
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(labels[i], style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      Text('${d.day}', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodInfo {
  final int periodIndex; // 0-based
  final String label; // '1교시' 등
  final TimeOfDay start;
  final TimeOfDay end;
  const _PeriodInfo({required this.periodIndex, required this.label, required this.start, required this.end});
}

// 커스텀 페인터: 네 모서리만 둥글고 내부 경계는 직선
class _OuterCornersPainter extends CustomPainter {
  final Color fill;
  final double radius;
  const _OuterCornersPainter({required this.fill, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );
    final Paint paint = Paint()..color = fill;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _OuterCornersPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.radius != radius;
  }
}

// 특정 코너만 둥글게 그리는 페인터
class _CornerPainter extends CustomPainter {
  final Color fill;
  final double radius;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _CornerPainter({
    required this.fill,
    required this.radius,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: topLeft ? Radius.circular(radius) : Radius.zero,
      topRight: topRight ? Radius.circular(radius) : Radius.zero,
      bottomLeft: bottomLeft ? Radius.circular(radius) : Radius.zero,
      bottomRight: bottomRight ? Radius.circular(radius) : Radius.zero,
    );
    final Paint paint = Paint()..color = fill;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.radius != radius ||
        oldDelegate.topLeft != topLeft ||
        oldDelegate.topRight != topRight ||
        oldDelegate.bottomLeft != bottomLeft ||
        oldDelegate.bottomRight != bottomRight;
  }
}
