import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/gsheet_service.dart';
import '../utils/responsive_helper.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<List<String>> timetable = List.generate(5, (_) => List.filled(7, ''));
  List<dynamic>? _rawTimetableData; // API 원본 데이터 저장
  bool isLoading = true;
  String? error;
  String? selectedGrade;
  String? selectedClass;
  DateTime currentWeekStart = DateTime.now().toUtc().add(
    const Duration(hours: 9),
  );
  bool _isTableView = true;
  int? _selectedListDayIndex; // 리스트 모드에서 선택된 요일(0:월~4:금)
  final Map<String, String> _shortenCache = {}; // 과목 축약 캐시
  final PageController _dayController = PageController();
  Map<String, String>? _electiveSubjects; // 선택과목 데이터
  bool _isMyTimetable = true; // true: 나의 시간표, false: 반별 시간표
  String? _myGrade; // 나의 시간표일 때의 학년
  String? _myClass; // 나의 시간표일 때의 반
  Map<int, int>? _classCounts; // 학년별 반 수 (스프레드시트에서 로드)
  Map<String, String>? _grade1SubjectMap; // 1학년 과목명 -> 줄임말 매핑
  Map<String, dynamic>? _grade2SubjectData; // 2학년 과목 데이터 (공통과목 + 선택과목)
  Map<String, dynamic>? _grade3SubjectData; // 3학년 과목 데이터 (공통과목 + 선택과목)
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
      // 로그인 안되어있으면 바로 반별 시간표로
      _isMyTimetable = false;
      // 저장된 마지막 선택 반 정보 불러오기
      _loadLastSelectedClass();
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

  // 마지막 선택한 반 정보 불러오기
  Future<void> _loadLastSelectedClass() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastGrade = prefs.getString('last_selected_grade');
      final lastClass = prefs.getString('last_selected_class');
      
      if (lastGrade != null && lastClass != null) {
        setState(() {
          selectedGrade = lastGrade;
          selectedClass = lastClass;
        });
      } else {
        // 저장된 정보가 없으면 기본값 1-1
        setState(() {
          selectedGrade = '1';
          selectedClass = '1';
        });
      }
    } catch (e) {
      // 오류 발생 시 기본값 1-1
      setState(() {
        selectedGrade = '1';
        selectedClass = '1';
      });
    }
  }

  // 마지막 선택한 반 정보 저장하기
  Future<void> _saveLastSelectedClass() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (selectedGrade != null && selectedClass != null) {
        await prefs.setString('last_selected_grade', selectedGrade!);
        await prefs.setString('last_selected_class', selectedClass!);
      }
    } catch (e) {
      print('마지막 선택 반 정보 저장 실패: $e');
    }
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
    
    // 현재 선택된 학년과 반
    final currentGrade = int.tryParse(selectedGrade ?? '1') ?? 1;
    final currentClass = int.tryParse(selectedClass ?? '1') ?? 1;
    
    // 학년별 반 수 가져오기
    final maxClassForCurrentGrade = _classCounts![currentGrade] ?? 11;
    
    // 학년과 반을 별도로 관리
    final ValueNotifier<int> selectedGradeNotifier = ValueNotifier<int>(currentGrade - 1); // 0-based
    final ValueNotifier<int> selectedClassNotifier = ValueNotifier<int>((currentClass - 1).clamp(0, maxClassForCurrentGrade - 1)); // 0-based
    
    // 학년 휠 컨트롤러
    final FixedExtentScrollController gradeController = FixedExtentScrollController(initialItem: currentGrade - 1);
    
    // 반 휠 컨트롤러를 동적으로 관리하기 위한 StatefulWidget 사용
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ClassPickerWidget(
        isDark: isDark,
        textColor: textColor,
        classCounts: _classCounts!,
        initialGrade: currentGrade - 1,
        initialClass: (currentClass - 1).clamp(0, maxClassForCurrentGrade - 1),
        gradeController: gradeController,
        selectedGradeNotifier: selectedGradeNotifier,
        selectedClassNotifier: selectedClassNotifier,
      ),
    ).then((_) async {
      // 모달이 닫힌 후 선택된 반으로 시간표 불러오기
      final finalGrade = selectedGradeNotifier.value + 1; // 1-based
      final finalClass = selectedClassNotifier.value + 1; // 1-based
      
      setState(() {
        selectedGrade = finalGrade.toString();
        selectedClass = finalClass.toString();
      });
      
      // 학년별 과목 정보 불러오기
      if (finalGrade == 1) {
        _grade1SubjectMap = await GSheetService.getGrade1Subjects();
        _grade2SubjectData = null;
        _grade3SubjectData = null;
      } else if (finalGrade == 2) {
        _grade1SubjectMap = null;
        _grade2SubjectData = await GSheetService.getGrade2Subjects();
        _grade3SubjectData = null;
      } else if (finalGrade == 3) {
        _grade1SubjectMap = null;
        _grade2SubjectData = null;
        _grade3SubjectData = await GSheetService.getGrade3Subjects();
      } else {
        _grade1SubjectMap = null;
        _grade2SubjectData = null;
        _grade3SubjectData = null;
      }
      
      // 마지막 선택 반 정보 저장
      _saveLastSelectedClass();
      // 캐시가 있으면 즉시 표시, 없으면 로딩 표시
      if (mounted) {
        loadTimetable(showLoading: false);
      }
      
      selectedGradeNotifier.dispose();
      selectedClassNotifier.dispose();
      gradeController.dispose();
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
        
        // 학년별 과목 정보 불러오기
        if (userInfo.grade == 1) {
          _grade1SubjectMap = await GSheetService.getGrade1Subjects();
          _grade2SubjectData = null;
          _grade3SubjectData = null;
        } else if (userInfo.grade == 2) {
          _grade1SubjectMap = null;
          _grade2SubjectData = await GSheetService.getGrade2Subjects();
          _grade3SubjectData = null;
        } else if (userInfo.grade == 3) {
          _grade1SubjectMap = null;
          _grade2SubjectData = null;
          _grade3SubjectData = await GSheetService.getGrade3Subjects();
        } else {
          _grade1SubjectMap = null;
          _grade2SubjectData = null;
          _grade3SubjectData = null;
        }
        
        loadTimetable();
      }
    } else {
      if (mounted) {
        // 로그인 안되어있으면 반별 시간표로
        if (!_isMyTimetable) {
          // 저장된 마지막 선택 반 정보가 없으면 기본값 사용
          if (selectedGrade == null || selectedClass == null) {
            await _loadLastSelectedClass();
          }
          setState(() {
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
  void _toggleTimetableMode() async {
    String? newGrade;
    setState(() {
      _isMyTimetable = !_isMyTimetable;
      if (_isMyTimetable) {
        // 나의 시간표로 전환
        selectedGrade = _myGrade;
        selectedClass = _myClass;
        newGrade = _myGrade;
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
        }
      } else {
        // 반별 시간표로 전환
        // 로그인된 사용자는 자신의 학년/반, 아니면 1-1
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null && _myGrade != null && _myClass != null) {
          // 로그인된 경우: 자신의 학년/반 표시
          selectedGrade = _myGrade;
          selectedClass = _myClass;
          newGrade = _myGrade;
        } else {
          // 로그인 안된 경우: 1-1 반 표시
          selectedGrade = '1';
          selectedClass = '1';
          newGrade = '1';
        }
        _electiveSubjects = null; // 선택과목 적용 안함
      }
    });
    
    // 학년별 과목 정보 불러오기
    if (newGrade == '1') {
      _grade1SubjectMap = await GSheetService.getGrade1Subjects();
      _grade2SubjectData = null;
      _grade3SubjectData = null;
    } else if (newGrade == '2') {
      _grade1SubjectMap = null;
      _grade2SubjectData = await GSheetService.getGrade2Subjects();
      _grade3SubjectData = null;
    } else if (newGrade == '3') {
      _grade1SubjectMap = null;
      _grade2SubjectData = null;
      _grade3SubjectData = await GSheetService.getGrade3Subjects();
    } else {
      _grade1SubjectMap = null;
      _grade2SubjectData = null;
      _grade3SubjectData = null;
    }
    
    if (mounted) {
      loadTimetable();
    }
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

  Future<void> loadTimetable({bool showLoading = true}) async {
    try {
      if (!mounted) return;
      
      // 학년별 과목 정보 불러오기
      if (selectedGrade == '1') {
        _grade1SubjectMap = await GSheetService.getGrade1Subjects();
        _grade2SubjectData = null;
        _grade3SubjectData = null;
      } else if (selectedGrade == '2') {
        _grade1SubjectMap = null;
        _grade2SubjectData = await GSheetService.getGrade2Subjects();
        _grade3SubjectData = null;
      } else if (selectedGrade == '3') {
        _grade1SubjectMap = null;
        _grade2SubjectData = null;
        _grade3SubjectData = await GSheetService.getGrade3Subjects();
      } else {
        _grade1SubjectMap = null;
        _grade2SubjectData = null;
        _grade3SubjectData = null;
      }
      
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
      
      bool hasValidCache = false;
      
      // 캐시가 있으면 (유효하든 오래되었든) 일단 표시
      if (cachedData != null) {
        try {
          final data = json.decode(cachedData);
          if (data['hisTimetable'] != null && data['hisTimetable'].length > 1) {
            final timetableData = data['hisTimetable'][1]['row'] as List;
            parseAndSetTimetable(timetableData);
            if (!mounted) return;
            hasValidCache = true;
            setState(() {
              isLoading = false;
              error = null;
            });
            
            // 캐시가 유효하면 백그라운드 업데이트, 오래되었으면 즉시 업데이트
            if ((now - lastUpdate) < cacheExpiry) {
              // 캐시가 유효하면 백그라운드에서만 업데이트
              updateTimetableInBackground();
            } else {
              // 캐시가 오래되었으면 백그라운드에서 업데이트하되, 사용자는 기존 데이터를 볼 수 있음
              updateTimetableInBackground();
            }
            
            // 캐시가 유효하면 여기서 종료
            if ((now - lastUpdate) < cacheExpiry) {
              return;
            }
          }
        } catch (e) {
          // 캐시 파싱 실패 시 API 호출로 진행
        }
      }
      
      // 캐시가 없거나 만료된 경우에만 로딩 표시
      // (캐시가 있어서 이미 표시했다면 로딩 표시 안함)
      if (showLoading && !hasValidCache) {
        setState(() {
          isLoading = true;
          error = null;
        });
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

      // 타임아웃 설정 (10초)
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('시간표 로딩 시간이 초과되었습니다.');
        },
      );
      
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

      // API 응답에서 데이터 인덱스 확인 (에러 응답이 아닌 경우)
      List<dynamic> timetableData;
      if (data['hisTimetable'].length > 3) {
        timetableData = data['hisTimetable'][3]['row'] as List;
      } else if (data['hisTimetable'].length > 1) {
        timetableData = data['hisTimetable'][1]['row'] as List;
      } else {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      parseAndSetTimetable(timetableData);

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      // 에러 발생 시 캐시된 데이터가 있으면 표시
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final data = json.decode(cachedData);
          if (data['hisTimetable'] != null && data['hisTimetable'].length > 1) {
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
    // 원본 데이터 저장 (리스트 뷰에서 사용)
    _rawTimetableData = timetableData;
    
    // 시간표 데이터 파싱
    final newTimetable = List.generate(5, (dayIndex) => List.filled(7, ''));
    // 날짜별로 모의고사 여부 체크를 위한 Map
    final Map<String, bool> isMockExamDay = {};

    // Helper function to normalize subject names for comparison (띄어쓰기만 제거)
    String normalize(String? s) {
      if (s == null || s.isEmpty) return '';
      return s.replaceAll(RegExp(r'\s+'), ''); // 띄어쓰기만 제거 (소문자 변환 없음)
    }
    
    // 안전한 contains 비교 함수
    bool safeContains(String? source, String? target) {
      if (source == null || target == null || source.isEmpty || target.isEmpty) {
        return false;
      }
      final normalizedSource = normalize(source);
      final normalizedTarget = normalize(target);
      return normalizedSource.contains(normalizedTarget);
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
          
          // 지필평가가 포함된 경우 선택과목 적용하지 않음
          if (!subject.contains('지필평가')) {
            // 1학년인 경우: 구글 시트에서 가져온 과목명 -> 줄임말 변환
            if (selectedGrade == '1' && _grade1SubjectMap != null && _grade1SubjectMap!.isNotEmpty) {
              bool found = false;
              for (var entry in _grade1SubjectMap!.entries) {
                final subjectName = entry.key;
                final abbreviation = entry.value;
                if (safeContains(subject, subjectName)) {
                  subject = abbreviation;
                  found = true;
                  break;
                }
              }
              if (!found) {
                // 줄임말에 포함되지 않는 경우 3글자로 줄이기
                subject = _shortenToThreeChars(subject);
              }
            }
            // 2학년인 경우: 구글 시트에서 가져온 공통과목 및 선택과목 처리
            else if (selectedGrade == '2' && _grade2SubjectData != null) {
              String? abbreviatedSubject;
              
              // 1. 선택과목 먼저 확인 (사용자 선택 우선)
              if (_electiveSubjects != null && _electiveSubjects!.isNotEmpty) {
                for (var entry in _electiveSubjects!.entries) {
                  final userSelectedSubjectName = entry.key.split('-').last;
                  if (safeContains(subject, userSelectedSubjectName)) {
                    abbreviatedSubject = entry.value;
                    break;
                  }
                }
              }
              
              // 2. 선택과목에 매칭되지 않으면 공통과목 확인
              if (abbreviatedSubject == null) {
                final commonSubjects = _grade2SubjectData!['common'] as Map<String, String>?;
                if (commonSubjects != null && commonSubjects.isNotEmpty) {
                  for (var entry in commonSubjects.entries) {
                    if (safeContains(subject, entry.key)) {
                      abbreviatedSubject = entry.value;
                      break;
                    }
                  }
                }
              }
              
              // 3. 공통과목에도 없으면 선택과목 세트에서 확인
              if (abbreviatedSubject == null) {
                final electiveSets = _grade2SubjectData!['elective'] as Map<int, Map<String, dynamic>>?;
                if (electiveSets != null && electiveSets.isNotEmpty) {
                  for (var setEntry in electiveSets.entries) {
                    final subjects = setEntry.value['subjects'] as Map<String, String>?;
                    if (subjects != null) {
                      for (var entry in subjects.entries) {
                        if (safeContains(subject, entry.key)) {
                          abbreviatedSubject = entry.value;
                          break;
                        }
                      }
                      if (abbreviatedSubject != null) break;
                    }
                  }
                }
              }

              if (abbreviatedSubject != null) {
                subject = abbreviatedSubject;
              } else {
                // 줄임말에 포함되지 않는 경우 3글자로 줄이기
                subject = _shortenToThreeChars(subject);
              }
            }
            // 3학년인 경우: 구글 시트에서 가져온 공통과목 및 선택과목 처리
            else if (selectedGrade == '3') {
              String? abbreviatedSubject;
              
              // _grade3SubjectData가 있는 경우에만 처리
              if (_grade3SubjectData != null) {
                // 1. 선택과목 먼저 확인 (사용자 선택 우선)
                if (_electiveSubjects != null && _electiveSubjects!.isNotEmpty) {
                  for (var entry in _electiveSubjects!.entries) {
                    final userSelectedSubjectName = entry.key.split('-').last;
                    if (safeContains(subject, userSelectedSubjectName)) {
                      abbreviatedSubject = entry.value;
                      break;
                    }
                  }
                }
                
                // 2. 선택과목에 매칭되지 않으면 공통과목 확인
                if (abbreviatedSubject == null) {
                  final commonSubjects = _grade3SubjectData!['common'] as Map<String, String>?;
                  if (commonSubjects != null && commonSubjects.isNotEmpty) {
                    for (var entry in commonSubjects.entries) {
                      if (safeContains(subject, entry.key)) {
                        abbreviatedSubject = entry.value;
                        break;
                      }
                    }
                  }
                }
                
                // 3. 공통과목에도 없으면 선택과목 세트에서 확인
                if (abbreviatedSubject == null) {
                  final electiveSets = _grade3SubjectData!['elective'] as Map<int, Map<String, dynamic>>?;
                  if (electiveSets != null && electiveSets.isNotEmpty) {
                    for (var setEntry in electiveSets.entries) {
                      final subjects = setEntry.value['subjects'] as Map<String, String>?;
                      if (subjects != null) {
                        for (var entry in subjects.entries) {
                          if (safeContains(subject, entry.key)) {
                            abbreviatedSubject = entry.value;
                            break;
                          }
                        }
                        if (abbreviatedSubject != null) break;
                      }
                    }
                  }
                }
              }

              if (abbreviatedSubject != null) {
                subject = abbreviatedSubject;
              } else {
                // 줄임말에 포함되지 않는 경우 3글자로 줄이기
                subject = _shortenToThreeChars(subject);
              }
            }
          }
          
          newTimetable[day][period] = subject; // 줄임말 적용된 버전
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
        timetable = newTimetable; // 줄임말 적용된 버전
      });
    }
  }
  
  // 리스트 뷰용: 원본 데이터에서 특정 요일/교시의 과목명 가져오기
  String? _getOriginalSubject(int dayIdx, int periodIndex) {
    if (_rawTimetableData == null) return null;
    
    for (var item in _rawTimetableData!) {
      final date = item['ALL_TI_YMD'].toString();
      final day = DateTime.parse(date).weekday - 1;
      if (day == dayIdx && day >= 0 && day < 5) {
        final period = int.parse(item['PERIO']) - 1;
        if (period == periodIndex && period >= 0 && period < 7) {
          return item['ITRT_CNTNT']?.toString();
        }
      }
    }
    return null;
  }

  // 줄임말에 포함되지 않는 과목을 3글자로 줄이는 함수
  String _shortenToThreeChars(String subject) {
    final cleaned = subject.trim();
    if (cleaned.isEmpty) return cleaned;
    if (cleaned.length < 2) return cleaned;
    if (cleaned.length >= 3) {
      final thirdChar = cleaned[2];
      final specialChars = RegExp(r'[\s,.";·]');
      if (specialChars.hasMatch(thirdChar)) {
        return cleaned.substring(0, 2);
      }
      return cleaned.substring(0, 3);
    }
    return cleaned;
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
    if (subject.contains('지필평가')) {
      _shortenCache[subject] = '지필';
      return '지필';
    }
    if (subject.contains('자기주도')) {
      _shortenCache[subject] = '자습';
      return '자습';
    }
    if (_shortenCache.containsKey(subject)) return _shortenCache[subject]!;
    for (var holiday in dayoff) {
      if (subject.contains(holiday)) return '휴일';
    }
    if (subject.contains('지구과학Ⅰ')) return '지구Ⅰ';
    if (subject.contains('지구과학Ⅱ')) return '지구ⅠⅠ';
    if (subject.contains('물리학Ⅰ')) return '물리Ⅰ';
    if (subject.contains('물리학Ⅱ')) return '물리ⅠⅠ';
    if (subject.contains('화학Ⅰ')) return '화학Ⅰ';
    if (subject.contains('화학Ⅱ')) return '화학ⅠⅠ';
    if (subject.contains('생명과학Ⅰ')) return '생명Ⅰ';
    if (subject.contains('생명과학Ⅱ')) return '생명ⅠⅠ';
    if (subject.contains('여행지리')) return '여지';
    if (subject.contains('데이터')) return '머신';
    if (subject.contains('심화 국어')) return '심국';
    if (subject.contains('사회·문화')) return '사문';
    if (subject.contains('사회문화')) return '사문';
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
    if (subject.contains('체육전공 실기')) return '체전';
    if (subject.contains('진로활동')) return '진로';
    if (subject.contains('프로그래밍')) return '프로';
    if (subject.contains('윤리와 사상')) return '윤사';
    if (subject.contains('통합과학')) return '통과';
    if (subject.contains('통합사회')) return '통사';
    if (subject.contains('공통수학')) return '수학';
    if (subject.contains('공통국어')) return '국어';
    if (subject.contains('과학탐구실험')) return '과탐실';
    if (subject.contains('영어권 문화')) return '영문';
    if (subject.contains('고전 읽기')) return '고전';
    if (subject.contains('화법과 작문')) return '화작';
    if (subject.contains('확률과 통계')) return '확통';
    if (subject.contains('언어와 매체')) return '언매';
    if (subject.contains('영어 독해와 작문')) return '영독';
    if (subject.contains('운동과 건강')) return '운건';
    if (subject.contains('생활과 과학')) return '생과';
    if (subject.contains('미술 창작')) return '미창';
    if (subject.contains('음악 연주')) return '음연';
    if (subject.contains('미술 전공 실기')) return '미전';
    if (subject.contains('음악 전공')) return '음전';
    if (subject.contains('전국연합')) return '모고';
    if (subject.contains('자율')) return '창체';
    if (subject.contains('한국사')) return '한사1';
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
                size: ResponsiveHelper.width(context, 64),
                color: textColor.withValues(alpha: 0.5),
              ),
              ResponsiveHelper.verticalSpace(context, 16),
              Text(
                error!,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 18,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              ResponsiveHelper.verticalSpace(context, 24),
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
        padding: EdgeInsets.zero,
        children: [
          ResponsiveHelper.verticalSpace(context, 80),
          Padding(
            padding: ResponsiveHelper.horizontalPadding(context, 24),
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
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 39,
                              color: textColor,
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
                                  padding: ResponsiveHelper.padding(context, left: 8),
                                  child: GestureDetector(
                                    onTap: _toggleTimetableMode,
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: ResponsiveHelper.width(context, 20),
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('right_empty')),
                        ),
                      ],
                    ),
                    ResponsiveHelper.verticalSpace(context, 14),
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
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 27,
                                  color: textColor,
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
                                  padding: ResponsiveHelper.padding(context, right: 0),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.arrow_back_ios,
                                      size: ResponsiveHelper.width(context, 16),
                                    ),
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
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 16,
                            color: textColor.withValues(alpha: 0.6),
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
                                  padding: ResponsiveHelper.padding(context, left: 0),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.arrow_forward_ios,
                                      size: ResponsiveHelper.width(context, 16),
                                    ),
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
                  width: ResponsiveHelper.width(context, 70),
                  height: ResponsiveHelper.height(context, 70),
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
              padding: ResponsiveHelper.horizontalPadding(context, 12),
              child: SizedBox(
                height: ResponsiveHelper.height(context, 90),
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
            padding: ResponsiveHelper.padding(context, right: 24),
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
            child: isLoading
                ? _buildLoadingView(textColor)
                : (_isTableView
                    ? _buildTableView(isDark, textColor)
                    : _buildListView(cardColor, textColor, isDark)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildLoadingView(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: textColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                '로딩중입니다',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTableView(bool isDark, Color textColor) {
    return Padding(
      padding: ResponsiveHelper.horizontalPadding(context, 16),
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final double gap = ResponsiveHelper.width(context, 8);
            final double itemWidth = (constraints.maxWidth - gap * 4) / 5;
            return Row(
              children: List.generate(5, (i) {
                final bool topLeft = i == 0;
                final bool topRight = i == 4;
                return Container(
                  width: itemWidth,
                  height: ResponsiveHelper.height(context, 36),
                  margin: EdgeInsets.only(right: i == 4 ? 0 : gap),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: CustomPaint(
                    painter: _CornerPainter(
                      fill: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                      radius: ResponsiveHelper.width(context, 12),
                      topLeft: topLeft,
                      topRight: topRight,
                      bottomLeft: false,
                      bottomRight: false,
                    ),
                    child: Center(
                      child: Text(
                        const ['월', '화', '수', '목', '금'][i],
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 15,
                          color: isDark ? AppColors.darkText : const Color(0xFF30302E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
          ResponsiveHelper.verticalSpace(context, 8),
          ...List.generate(7, (row) {
            return LayoutBuilder(builder: (context, constraints) {
              final double gap = ResponsiveHelper.width(context, 8);
              final double itemWidth = (constraints.maxWidth - gap * 4) / 5;
              return Padding(
                padding: ResponsiveHelper.padding(context, bottom: 8),
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
                      height: ResponsiveHelper.height(context, 50),
                      margin: EdgeInsets.only(right: dayIdx == 4 ? 0 : gap),
                      decoration: const BoxDecoration(color: Colors.transparent),
                      child: CustomPaint(
                        painter: _CornerPainter(
                          fill: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          radius: ResponsiveHelper.width(context, 12),
                          topLeft: false,
                          topRight: false,
                          bottomLeft: bottomLeft,
                          bottomRight: bottomRight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: ResponsiveHelper.horizontalPadding(context, 8),
                            child: Text(
                              // 1학년, 2학년, 3학년은 이미 parseAndSetTimetable에서 줄임말로 변환되었으므로 shortenSubject 호출 안함
                              (selectedGrade == '1' || selectedGrade == '2' || selectedGrade == '3') ? cell : shortenSubject(cell),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 15,
                                color: isDark ? AppColors.darkText : const Color(0xFF30302E),
                                fontWeight: FontWeight.w600,
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
      height: ResponsiveHelper.height(context, 500), // 적절한 고정 높이 설정
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
            padding: ResponsiveHelper.horizontalPadding(context, 16),
            child: Column(
              children: [
                ...periods.where((info) {
                  final subject = _getOriginalSubject(dayIdx, info.periodIndex);
                  return subject != null && subject.isNotEmpty;
                }).map((info) {
                  final subject = _getOriginalSubject(dayIdx, info.periodIndex) ?? '';
                  final listItemBgColor = isDark 
                      ? cardColor 
                      : const Color(0xFFF5F5F5);
                  
                  return Container(
                    width: double.infinity,
                    margin: ResponsiveHelper.padding(context, bottom: 8),
                    padding: ResponsiveHelper.padding(context, all: 5),
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: CustomPaint(
                      painter: _OuterCornersPainter(
                        fill: listItemBgColor,
                        radius: ResponsiveHelper.width(context, 20),
                      ),
                      child: Padding(
                        padding: ResponsiveHelper.padding(
                          context,
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${info.label} | ${_formatAmPm(info.start)} ${_formatAmPm(info.end)}',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 13,
                                color: textColor.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w400,
                                height: 1.28,
                              ),
                            ),
                            ResponsiveHelper.verticalSpace(context, 6),
                            Text(
                              _formatSubjectName(subject),
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 18,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                height: 1.28,
                              ),
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

  String _formatSubjectName(String subject) {
    if (subject.contains('지필평가')) {
      final index = subject.indexOf('지필평가');
      if (index != -1) {
        final afterIndex = index + '지필평가'.length;
        if (afterIndex < subject.length && subject[afterIndex] != ' ') {
          return subject.substring(0, afterIndex) + ' ' + subject.substring(afterIndex);
        }
      }
    }
    return subject;
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
    final itemWidth = ResponsiveHelper.width(context, 44.0);
    final sidePadding = ResponsiveHelper.width(context, 13.0);
    final capsuleWidth = ResponsiveHelper.width(context, 44.0);
    final capsuleHeight = ResponsiveHelper.height(context, 60.0);
    
    Color getDayColor(int index) {
      if (index == 0) return const Color.fromRGBO(236, 69, 69, 1);
      if (index == 6) return const Color.fromARGB(255, 203, 204, 208);
      return textColor;
    }
    
    return Column(
      children: [
        SizedBox(
          height: ResponsiveHelper.height(context, 80),
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
                      height: ResponsiveHelper.height(context, 80),
                      child: GestureDetector(
                        onTap: () => onTapDay?.call(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              labels[i],
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 15,
                                color: getDayColor(i),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ResponsiveHelper.verticalSpace(context, 6),
                            Text(
                              '${dates[i].day}',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 15,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
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
                        top: (ResponsiveHelper.height(context, 80) - capsuleHeight) / 2,
                        width: capsuleWidth,
                        height: capsuleHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: capsuleFill,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 25)),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.35),
                              width: ResponsiveHelper.width(context, 1),
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

class _ClassPickerWidget extends StatefulWidget {
  final bool isDark;
  final Color textColor;
  final Map<int, int> classCounts;
  final int initialGrade;
  final int initialClass;
  final FixedExtentScrollController gradeController;
  final ValueNotifier<int> selectedGradeNotifier;
  final ValueNotifier<int> selectedClassNotifier;

  const _ClassPickerWidget({
    required this.isDark,
    required this.textColor,
    required this.classCounts,
    required this.initialGrade,
    required this.initialClass,
    required this.gradeController,
    required this.selectedGradeNotifier,
    required this.selectedClassNotifier,
  });

  @override
  State<_ClassPickerWidget> createState() => _ClassPickerWidgetState();
}

class _ClassPickerWidgetState extends State<_ClassPickerWidget> {
  FixedExtentScrollController? _classController;
  int _currentGrade = 0;

  @override
  void initState() {
    super.initState();
    _currentGrade = widget.initialGrade;
    _createClassController();
    
    // 학년 변경 리스너 추가
    widget.selectedGradeNotifier.addListener(_onGradeChanged);
  }

  void _createClassController() {
    if (!mounted) return;
    final selectedGrade = _currentGrade + 1; // 1-based
    final maxClass = widget.classCounts[selectedGrade] ?? 11;
    final currentClass = widget.selectedClassNotifier.value + 1; // 1-based
    final adjustedClassIndex = (currentClass > maxClass) ? maxClass - 1 : (currentClass - 1);
    
    _classController?.dispose();
    _classController = FixedExtentScrollController(
      initialItem: adjustedClassIndex.clamp(0, maxClass - 1),
    );
    if (mounted) {
      widget.selectedClassNotifier.value = adjustedClassIndex.clamp(0, maxClass - 1);
    }
  }

  void _onGradeChanged() {
    if (!mounted) return;
    final newGrade = widget.selectedGradeNotifier.value;
    if (newGrade != _currentGrade) {
      setState(() {
        _currentGrade = newGrade;
        _createClassController();
      });
    }
  }

  @override
  void dispose() {
    widget.selectedGradeNotifier.removeListener(_onGradeChanged);
    _classController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.selectedGradeNotifier,
      builder: (context, selectedGradeIndex, _) {
        final selectedGrade = selectedGradeIndex + 1; // 1-based
        final maxClass = widget.classCounts[selectedGrade] ?? 11;
        
        return ValueListenableBuilder<int>(
          valueListenable: widget.selectedClassNotifier,
          builder: (context, selectedClassIndex, __) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
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
                      color: widget.textColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 제목
                  Text(
                    '반 선택',
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 학년과 반 휠 선택기 (나란히 배치)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 학년 휠
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: widget.gradeController,
                            itemExtent: 50,
                            physics: const FixedExtentScrollPhysics(),
                            perspective: 0.003,
                            diameterRatio: 1.5,
                            squeeze: 1.0,
                            onSelectedItemChanged: (index) {
                              if (mounted && index >= 0 && index < 3) {
                                widget.selectedGradeNotifier.value = index;
                              }
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 3,
                              builder: (context, index) {
                                if (index < 0 || index >= 3) return const SizedBox();
                                final grade = index + 1;
                                final isCenter = selectedGradeIndex == index;
                                
                                return Center(
                                  child: Text(
                                    '$grade 학년',
                                    style: TextStyle(
                                      color: isCenter 
                                          ? Colors.white 
                                          : widget.textColor.withValues(alpha: 0.5),
                                      fontSize: isCenter ? 24 : 20,
                                      fontWeight: isCenter ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // 반 휠
                        Expanded(
                          child: _classController != null
                              ? ListWheelScrollView.useDelegate(
                                  controller: _classController!,
                                  itemExtent: 50,
                                  physics: const FixedExtentScrollPhysics(),
                                  perspective: 0.003,
                                  diameterRatio: 1.5,
                                  squeeze: 1.0,
                                  onSelectedItemChanged: (index) {
                                    if (mounted && index >= 0 && index < maxClass) {
                                      widget.selectedClassNotifier.value = index;
                                    }
                                  },
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: maxClass,
                                    builder: (context, index) {
                                      if (index < 0 || index >= maxClass) return const SizedBox();
                                      final classNum = index + 1;
                                      final isCenter = selectedClassIndex == index;
                                      
                                      return Center(
                                        child: Text(
                                          '$classNum 반',
                                          style: TextStyle(
                                            color: isCenter 
                                                ? Colors.white 
                                                : widget.textColor.withValues(alpha: 0.5),
                                            fontSize: isCenter ? 24 : 20,
                                            fontWeight: isCenter ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}