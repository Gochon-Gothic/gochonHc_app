import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/gsheet_service.dart';


class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<List<String>> timetable = List.generate(5, (_) => List.filled(7, ''));
  bool isLoading = true;
  String? error;
  String? selectedGrade;
  String? selectedClass;
  DateTime currentWeekStart = DateTime.now().toUtc().add(
    const Duration(hours: 9),
  );
  bool isNextWeek = false;
  bool _isTableView = true; // true: 표, false: 리스트
  int? _selectedListDayIndex; // 리스트 모드에서 선택된 요일(0:월~4:금)
  final Map<String, String> _shortenCache = {}; // 과목 축약 캐시
  final PageController _dayController = PageController();
  Map<String, String>? _electiveSubjects; // 선택과목 데이터
  bool _isMyTimetable = true; // true: 나의 시간표, false: 반별 시간표
  String? _myGrade; // 나의 시간표일 때의 학년
  String? _myClass; // 나의 시간표일 때의 반
  Map<int, int>? _classCounts; // 학년별 반 수 (스프레드시트에서 로드)
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
    
    // 로그인 상태 확인하여 초기 모드 설정
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      // 로그인 안되어있으면 바로 반별 시간표로 (1-1)
      _isMyTimetable = false;
      selectedGrade = '1';
      selectedClass = '1';
    }
    
    _loadClassCounts();
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

  // 학년별 반 수 로드
  Future<void> _loadClassCounts() async {
    try {
      final counts = await GSheetService.getClassCounts();
      if (mounted) {
        setState(() {
          _classCounts = counts;
        });
      }
    } catch (e) {
      // 오류 발생 시 기본값 유지
      print('학년별 반 수 로드 실패: $e');
    }
  }

  // 반 선택 메뉴 표시
  void _showClassPicker(BuildContext context, bool isDark, Color textColor) {
    if (_classCounts == null) return;
    
    // 모든 학년-반 조합 생성
    final List<MapEntry<int, int>> classOptions = [];
    for (int grade = 1; grade <= 3; grade++) {
      final maxClass = _classCounts![grade] ?? 11;
      for (int classNum = 1; classNum <= maxClass; classNum++) {
        classOptions.add(MapEntry(grade, classNum));
      }
    }
    
    // 현재 선택된 반의 인덱스 찾기
    final currentGrade = int.tryParse(selectedGrade ?? '1') ?? 1;
    final currentClass = int.tryParse(selectedClass ?? '1') ?? 1;
    int initialIndex = 0;
    for (int i = 0; i < classOptions.length; i++) {
      if (classOptions[i].key == currentGrade && classOptions[i].value == currentClass) {
        initialIndex = i;
        break;
      }
    }
    
    final FixedExtentScrollController scrollController = FixedExtentScrollController(initialItem: initialIndex);
    final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(initialIndex);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, _) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 상단 핸들 바
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // 제목
                Text(
                  '반 선택',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                // 휠 스크롤 선택기
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: scrollController,
                    itemExtent: 50,
                    physics: const FixedExtentScrollPhysics(),
                    perspective: 0.003,
                    diameterRatio: 1.5,
                    squeeze: 1.0,
                    onSelectedItemChanged: (index) {
                      if (index >= 0 && index < classOptions.length) {
                        selectedIndexNotifier.value = index;
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: classOptions.length,
                      builder: (context, index) {
                        if (index < 0 || index >= classOptions.length) return const SizedBox();
                        final option = classOptions[index];
                        final isCenter = selectedIndex == index;
                        
                        return Center(
                          child: Text(
                            '${option.key}학년 ${option.value}반',
                            style: TextStyle(
                              color: isCenter 
                                  ? Colors.white 
                                  : textColor.withValues(alpha: 0.5),
                              fontSize: isCenter ? 24 : 20,
                              fontWeight: isCenter ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      // 모달이 닫힌 후 선택된 반으로 시간표 불러오기
      final finalIndex = selectedIndexNotifier.value;
      if (finalIndex >= 0 && finalIndex < classOptions.length) {
        final selectedOption = classOptions[finalIndex];
        setState(() {
          selectedGrade = selectedOption.key.toString();
          selectedClass = selectedOption.value.toString();
        });
        loadTimetable();
      }
      selectedIndexNotifier.dispose();
    });
  }

  Future<void> _initMyClassAndLoad() async {
    final userInfo = await UserService.instance.getUserInfo();
    if (userInfo != null) {
      if (mounted) {
        setState(() {
          _myGrade = userInfo.grade.toString();
          _myClass = userInfo.classNum.toString();
          // 나의 시간표 모드일 때만 사용자 정보 사용
          if (_isMyTimetable) {
            selectedGrade = _myGrade;
            selectedClass = _myClass;
          } else {
            // 반별 시간표 모드: 로그인된 사용자는 자신의 학년/반 표시
            selectedGrade = _myGrade ?? '1';
            selectedClass = _myClass ?? '1';
          }
        });
        // 선택과목 데이터 불러오기 (나의 시간표일 때만)
        if (_isMyTimetable) {
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            _electiveSubjects = await UserService.instance.getElectiveSubjects(currentUser.uid);
          }
        } else {
          _electiveSubjects = null; // 반별 시간표일 때는 선택과목 적용 안함
        }
        loadTimetable();
      }
    } else {
      if (mounted) {
        // 로그인 안되어있으면 반별 시간표로
        if (!_isMyTimetable) {
          setState(() {
            selectedGrade = '1';
            selectedClass = '1';
            isLoading = false;
          });
          loadTimetable();
        } else {
          setState(() {
            isLoading = false;
            error = '사용자 정보를 찾을 수 없습니다. 초기 설정을 완료해주세요.';
          });
        }
      }
    }
  }
  
  // 나의 시간표 <-> 반별 시간표 전환
  void _toggleTimetableMode() {
    setState(() {
      _isMyTimetable = !_isMyTimetable;
      if (_isMyTimetable) {
        // 나의 시간표로 전환
        selectedGrade = _myGrade;
        selectedClass = _myClass;
        // 선택과목 데이터 다시 불러오기
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          UserService.instance.getElectiveSubjects(currentUser.uid).then((subjects) {
            if (mounted) {
              setState(() {
                _electiveSubjects = subjects;
              });
              loadTimetable();
            }
          });
        } else {
          _electiveSubjects = null;
          loadTimetable();
        }
      } else {
        // 반별 시간표로 전환
        // 로그인된 사용자는 자신의 학년/반, 아니면 1-1
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null && _myGrade != null && _myClass != null) {
          // 로그인된 경우: 자신의 학년/반 표시
          selectedGrade = _myGrade;
          selectedClass = _myClass;
        } else {
          // 로그인 안된 경우: 1-1 반 표시
          selectedGrade = '1';
          selectedClass = '1';
        }
        _electiveSubjects = null; // 선택과목 적용 안함
        loadTimetable();
      }
    });
  }
  int getPeriodCount(int dayIndex) {
    switch (dayIndex) {
      case 0: // 월
      case 4: // 금
        return 7;
      default: // 화, 수, 목
        return 6;
    }
  }
  String getDateRange() {
    final weekStart = currentWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 4)); 
    final formatter = DateFormat('yyyyMMdd');
    return '${formatter.format(weekStart)}:${formatter.format(weekEnd)}';
  }
  List<DateTime> getWeekDates() {
    final monday = currentWeekStart;
    final sunday = monday.subtract(const Duration(days: 1));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }
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

  // 현재 표시 중인 주가 다음주인지 확인
  bool _isNextWeek() {
    final thisWeekStart = getCurrentWeekStart();
    return currentWeekStart.isAfter(thisWeekStart);
  }

  // 다음주로 이동
  void _goToNextWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    });
    loadTimetable();
  }

  // 이전주로 이동
  void _goToPreviousWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    });
    loadTimetable();
  }

  Future<void> loadTimetable() async {
    try {
      if (!mounted) return;
      
      setState(() {
        isLoading = true;
        error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final cacheKey =
          'timetable_${selectedGrade}_${selectedClass}_${getDateRange()}';
      final cachedData = prefs.getString(cacheKey);
      final lastUpdate = prefs.getInt('${cacheKey}_lastUpdate') ?? 0;
      final now =
          DateTime.now()
              .toUtc()
              .add(const Duration(hours: 9))
              .millisecondsSinceEpoch;
      final cacheExpiry = 3600000; // 1시간 (밀리초) 
      if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
        final data = json.decode(cachedData);
        if (data['hisTimetable'] != null && data['hisTimetable'].length > 1) {
          final timetableData = data['hisTimetable'][1]['row'] as List;
          parseAndSetTimetable(timetableData);
          if (!mounted) return;
          setState(() {
            isLoading = false;
          });
          updateTimetableInBackground();
          return;
        }
      }
      await fetchTimetableFromAPI(prefs, cacheKey);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }
  Future<void> fetchTimetableFromAPI(
    SharedPreferences prefs,
    String cacheKey,
  ) async {
    try {
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
          isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body);
      if (data['hisTimetable'] == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt(
        '${cacheKey}_lastUpdate',
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 9))
            .millisecondsSinceEpoch,
      );

      final timetableData = data['hisTimetable'][3]['row'] as List;
      parseAndSetTimetable(timetableData);

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final data = json.decode(cachedData);
          if (data['hisTimetable'] != null) {
            final timetableData = data['hisTimetable'][1]['row'] as List;
            parseAndSetTimetable(timetableData);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }
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
          await prefs.setString(cacheKey, response.body);
          await prefs.setInt(
            '${cacheKey}_lastUpdate',
            DateTime.now()
                .toUtc()
                .add(const Duration(hours: 9))
                .millisecondsSinceEpoch,
          );
          if (mounted) {
            final timetableData = data['hisTimetable'][1]['row'] as List;
            parseAndSetTimetable(timetableData);
            setState(() {}); // UI 새로고침
          }
        }
      }
    } catch (e) {
    }
  }

  // 시간표 데이터 파싱 및 설정 (코드 재사용성 향상)
  void parseAndSetTimetable(List<dynamic> timetableData) {
    // 시간표 데이터 파싱
    final newTimetable = List.generate(5, (dayIndex) => List.filled(7, ''));
    // 날짜별로 모의고사 여부 체크를 위한 Map
    final Map<String, bool> isMockExamDay = {};

    // 선택과목 세트 정의 (elective_setup_screen.dart와 동일)
    const set1 = ['지구과학Ⅰ', '물리학Ⅰ', '화학Ⅰ', '생명과학Ⅰ', '경제', '한국지리', '세계사', '윤리와 사상', '정치와 법'];
    const set2 = ['음악 연주', '미술 창작'];
    const set3 = ['일본어Ⅰ', '프로그래밍', '중국어Ⅰ'];
    const set4 = ['기하', '고전 읽기', '영어권 문화'];
    final allSets = [set1, set2, set3, set4];

    // 과목이 어느 세트에 속하는지 확인하는 함수
    int? getSetNumber(String subject) {
      for (int i = 0; i < allSets.length; i++) {
        if (allSets[i].any((s) => subject.contains(s))) {
          return i + 1; // 세트 번호는 1부터 시작
        }
      }
      return null;
    }

    // 세트 내의 정확한 과목명 반환
    String cleanSubject(String subject, int setNumber) {
      final set = [null, set1, set2, set3, set4][setNumber];
      if (set != null) {
        return set.firstWhere(
          (s) => s.isNotEmpty && subject.contains(s),
          orElse: () => subject,
        );
      }
      return subject;
    }

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
          String subject = item['ITRT_CNTNT'];
          
          // 선택과목 적용: 해당 과목이 선택과목에 있으면 교체
          if (_electiveSubjects != null && _electiveSubjects!.isNotEmpty) {
            final setNum = getSetNumber(subject);
            if (setNum != null) {
              final clean = cleanSubject(subject, setNum);
              final key = '$setNum-$clean';
              if (_electiveSubjects!.containsKey(key)) {
                subject = _electiveSubjects![key]!;
              }
            }
          }
          
          newTimetable[day][period] = subject;
        }
      }
    }
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
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                child: child,
                              ),
                            );
                          },
                          child: (!_isMyTimetable && AuthService.instance.currentUser != null)
                              ? Padding(
                                  key: const ValueKey('left_arrow'),
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: _toggleTimetableMode,
                                    child: Icon(
                                      Icons.arrow_back_ios,
                                      size: 20,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('left_empty')),
                        ),
                        // 제목 텍스트
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.1, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _isMyTimetable ? '나의 시간표' : '반별 시간표',
                            key: ValueKey(_isMyTimetable),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 39,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                child: child,
                              ),
                            );
                          },
                          child: (_isMyTimetable && AuthService.instance.currentUser != null)
                              ? Padding(
                                  key: const ValueKey('right_arrow'),
                                  padding: const EdgeInsets.only(left: 8),
                                  child: GestureDetector(
                                    onTap: _toggleTimetableMode,
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 20,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('right_empty')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 반 선택 텍스트 (반별 시간표 모드일 때만 표시)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: !_isMyTimetable
                          ? GestureDetector(
                              key: const ValueKey('class_text'),
                              onTap: () => _showClassPicker(context, isDark, textColor),
                              child: Text(
                                '${selectedGrade ?? '1'}학년 ${selectedClass ?? '1'}반',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('class_text_empty')),
                    ),
                    // 주간 텍스트
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 왼쪽 화살표 (다음주일 때만 표시)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                child: child,
                              ),
                            );
                          },
                          child: _isNextWeek()
                              ? Padding(
                                  key: const ValueKey('left_arrow'),
                                  padding: const EdgeInsets.only(right: 0),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                                    color: textColor.withValues(alpha: 0.6),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _goToPreviousWeek,
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('left_empty')),
                        ),
                        Text(
                          '${DateFormat('MM/dd').format(currentWeekStart)}~${DateFormat('MM/dd').format(currentWeekStart.add(const Duration(days: 4)))}',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        // 오른쪽 화살표 (이번주일 때만 표시)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                child: child,
                              ),
                            );
                          },
                          child: !_isNextWeek()
                              ? Padding(
                                  key: const ValueKey('right_arrow'),
                                  padding: const EdgeInsets.only(left: 0),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                    color: textColor.withValues(alpha: 0.6),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _goToNextWeek,
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('right_empty')),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 70,
                  height: 70,
                  child: SvgPicture.asset(
                    'assets/images/gochon_logo.svg',
                    semanticsLabel: 'Gochon Logo',
                  ),
                ),
              ],
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.only(right: 24),
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
          const SizedBox(height: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isTableView
                ? _buildTableView(isDark, textColor)
                : _buildListView(cardColor, textColor, isDark),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildTableView(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
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
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    const itemWidth = 44.0;
    const sidePadding = 13.0;
    const capsuleWidth = 44.0;
    const capsuleHeight = 60.0;
    
    Color getDayColor(int index) {
      if (index == 0) return const Color.fromRGBO(236, 69, 69, 1);
      if (index == 6) return const Color.fromARGB(255, 203, 204, 208);
      return textColor;
    }
    
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalItemWidth = 7 * itemWidth;
              final gapBetweenDays = (constraints.maxWidth - totalItemWidth - (2 * sidePadding)) / 6;
              final startX = sidePadding;
              
              final positions = List.generate(7, (i) {
                return startX + i * (itemWidth + gapBetweenDays);
              });
              
              return Stack(
                children: [
                  ...List.generate(7, (i) {
                    return Positioned(
                      left: positions[i],
                      top: 0,
                      width: itemWidth,
                      height: 80,
                      child: GestureDetector(
                        onTap: () => onTapDay?.call(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              labels[i],
                              style: TextStyle(color: getDayColor(i), fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${dates[i].day}',
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  AnimatedBuilder(
                    animation: controller ?? const AlwaysStoppedAnimation(0.0),
                    builder: (context, _) {
                      double page = 0.0;
                      if (controller?.positions.isNotEmpty == true) {
                        page = (controller!.page ?? 0.0).clamp(0, 4);
                      }
                      
                      final dayIndexDouble = page + 1.0;
                      final int lowerIndex = dayIndexDouble.floor().clamp(1, 5);
                      final int upperIndex = (dayIndexDouble.ceil()).clamp(1, 5);
                      final double t = dayIndexDouble - lowerIndex;
                      
                      final double lowerX = positions[lowerIndex] + (itemWidth / 2);
                      final double upperX = positions[upperIndex] + (itemWidth / 2);
                      final double centerX = lowerX + (upperX - lowerX) * t;
                      final double leftForCapsule = centerX - (capsuleWidth / 2);
                      final capsuleFill = isDark 
                          ? const Color.fromRGBO(255, 255, 255, 0.12) 
                          : const Color.fromRGBO(0, 0, 0, 0.08);

                      return Positioned(
                        left: leftForCapsule,
                        top: (80 - capsuleHeight) / 2,
                        width: capsuleWidth,
                        height: capsuleHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: capsuleFill,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.35),
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
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
