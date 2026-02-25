import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

/// 선택과목 설정: GSheet/ApiService로 슬롯 조회 → 세트별 과목 선택 → Firestore 저장
///
/// [로직 흐름]
/// 1. initState: getGrade2Subjects/getGrade3Subjects → 시간표 API 2주치 → _extractTimetableRows로 슬롯 파싱
/// 2. _slotsBySet: 세트별(1~4) 슬롯 목록, _setRequiredCounts: 세트당 필수 선택 수
/// 3. 사용자가 세트별로 과목 선택 → _selections에 저장
/// 4. 제출: saveElectiveSubjects(electiveSubjects) → isFromLogin이면 MainScreen, 아니면 pop
import '../services/user_service.dart';
import '../services/gsheet_service.dart';
import '../utils/preference_manager.dart';
import '../theme_colors.dart';
import '../utils/responsive_helper.dart';

class ElectiveSetupScreen extends StatefulWidget {
  final String userEmail;
  final String uid;
  final int grade;
  final int classNum;
  final bool isEditMode;
  final bool isFromLogin;

  const ElectiveSetupScreen({
    super.key,
    required this.userEmail,
    required this.uid,
    required this.grade,
    required this.classNum,
    this.isEditMode = false,
    this.isFromLogin = false,
  });

  @override
  State<ElectiveSetupScreen> createState() => _ElectiveSetupScreenState();
}

class _ElectiveSetupScreenState extends State<ElectiveSetupScreen> {
  bool _isLoading = true;
  Map<int, List<ElectiveSlot>> _slotsBySet = {}; // 세트별로 그룹화된 슬롯
  final Map<String, String> _selections = {}; // key: 'set-slotKey', value: 선택한 과목
  Map<int, String> _setNames = {}; // 세트 번호 -> 세트 이름 (구글 시트에서 가져옴)
  final Map<int, int> _setRequiredCounts = {}; // 세트 번호 -> 선택해야 하는 과목 수 (구글 시트에서 가져옴)
  final Map<int, List<String>> _sheetSubjectsBySet = {}; // 세트 번호 -> 시트에서 온 과목 리스트
  String? _error;

  static const _apiKey = '2cf24c119b434f93b2f916280097454a';
  static const _eduOfficeCode = 'J10';
  static const _schoolCode = '7531375';
  static const _set1 = [
    '지구과학Ⅰ',
    '물리학Ⅰ',
    '화학Ⅰ',
    '생명과학Ⅰ',
    '경제',
    '한국지리',
    '세계사',
    '윤리와 사상',
    '정치와 법',
    ];
  static const _set2 = [
    '음악 연주',
    '미술 창작',
  ];
  static const _set3 = [
    '일본어Ⅰ',
    '프로그래밍',
    '중국어Ⅰ',
  ];
  static const _set4 = [
    '기하',
    '고전 읽기',
    '영어권 문화',
  ];
  static const _days = ['월', '화', '수', '목', '금'];
  static const _dayOrder = {'월': 0, '화': 1, '수': 2, '목': 3, '금': 4};

  List<dynamic>? _extractTimetableRows(dynamic decoded) {
    if (decoded is! Map || decoded['hisTimetable'] is! List) return null;
    final list = decoded['hisTimetable'] as List<dynamic>;

    List<dynamic>? rowsAt(int idx) {
      if (idx < 0 || idx >= list.length) return null;
      final item = list[idx];
      if (item is Map && item['row'] is List) {
        return item['row'] as List<dynamic>;
      }
      return null;
    }

    return rowsAt(3) ?? rowsAt(2) ?? rowsAt(1);
  }

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  DateTime _getWeekStart() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final weekday = now.weekday;
    return weekday >= 6 
        ? now.add(Duration(days: 8 - weekday))
        : now.subtract(Duration(days: weekday - 1));
  }

  Future<void> _loadSlots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 재시도/재진입 시 이전 상태 초기화
    _slotsBySet = {};
    _selections.clear();
    _setNames = {};
    _setRequiredCounts.clear();
    _sheetSubjectsBySet.clear();

    try {
      // 2학년, 3학년인 경우 구글 시트에서 선택과목 정보 가져오기
      Map<int, Map<String, String>>? gsheetElectiveSubjects;
      if (widget.grade == 2 || widget.grade == 3) {
        final gradeData = widget.grade == 2 
            ? await GSheetService.getGrade2Subjects()
            : await GSheetService.getGrade3Subjects();
        final electiveSets = gradeData['elective'] as Map<int, Map<String, dynamic>>?;
        if (electiveSets != null) {
          gsheetElectiveSubjects = {};
          electiveSets.forEach((setNum, setData) {
            final setName = setData['setName']?.toString();

            // subjects: Map<String, dynamic> -> Map<String, String> 로 안전하게 변환
            Map<String, String>? subjects;
            final rawSubjects = setData['subjects'];
            if (rawSubjects is Map) {
              subjects = {};
              rawSubjects.forEach((key, value) {
                if (key != null && value != null) {
                  subjects![key.toString()] = value.toString();
                }
              });
            }

            // requiredCount: int 또는 String일 수 있으므로 변환
            int? requiredCount;
            final rcVal = setData['requiredCount'];
            if (rcVal is int) {
              requiredCount = rcVal;
            } else if (rcVal is String) {
              requiredCount = int.tryParse(rcVal);
            }

            if (setName != null) {
              _setNames[setNum] = setName;
            }
            if (subjects != null && subjects.isNotEmpty) {
              gsheetElectiveSubjects![setNum] = subjects;
              _sheetSubjectsBySet[setNum] = subjects.keys.toList();
            }
            if (requiredCount != null && requiredCount > 0) {
              _setRequiredCounts[setNum] = requiredCount;
            }
          });
        }
      }

      final thisWeekStart = _getWeekStart();
      final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
      final formatter = DateFormat('yyyyMMdd');
      
      final responses = await Future.wait([
        ApiService.instance.getTimetable(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: widget.grade.toString(),
          classNum: widget.classNum.toString(),
          fromDate: formatter.format(thisWeekStart),
          toDate: formatter.format(thisWeekStart.add(const Duration(days: 4))),
        ),
        ApiService.instance.getTimetable(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: widget.grade.toString(),
          classNum: widget.classNum.toString(),
          fromDate: formatter.format(nextWeekStart),
          toDate: formatter.format(nextWeekStart.add(const Duration(days: 4))),
        ),
      ]);

      // 세트별로 슬롯을 저장할 맵: {세트번호: {과목명: 슬롯}}
      final slotsBySet = <int, Map<String, ElectiveSlot>>{};
      
      // 2학년/3학년은 시트에 있는 세트 번호를 그대로 사용, 그 외는 기존 1~4 사용
      final List<int> targetSetNumbers =
          ((widget.grade == 2 || widget.grade == 3) &&
                  gsheetElectiveSubjects != null &&
                  gsheetElectiveSubjects.isNotEmpty)
              ? (gsheetElectiveSubjects.keys.toList()..sort())
              : [1, 2, 3, 4];

      // 세트별로 검색
      for (final setNum in targetSetNumbers) {
        slotsBySet[setNum] = {};

        for (int weekIdx = 0; weekIdx < responses.length; weekIdx++) {
          final data = responses[weekIdx].data;
          final rows = _extractTimetableRows(data);
          if (rows == null) continue;

          for (var item in rows) {
            final subject = (item['ITRT_CNTNT'] as String? ?? '').trim();
            final dateStr = item['ALL_TI_YMD'] as String? ?? '';
            final periodStr = item['PERIO'] as String? ?? '';
            
            // 2학년, 3학년인 경우 구글 시트의 과목명으로 세트 확인
            int? subjectSetNum;
            if ((widget.grade == 2 || widget.grade == 3) && gsheetElectiveSubjects != null) {
              for (var setEntry in gsheetElectiveSubjects.entries) {
                for (var subEntry in setEntry.value.entries) {
                  if (subject.contains(subEntry.key)) {
                    subjectSetNum = setEntry.key;
                    break;
                  }
                }
                if (subjectSetNum != null) break;
              }
            } else {
              // 구글 시트 데이터가 없는 경우 기존 로직 사용 (하위 호환성)
              subjectSetNum = _getSetNumber(subject);
            }
            
            if (subjectSetNum != setNum || dateStr.isEmpty || periodStr.isEmpty) {
              continue;
            }

            try {
              final date = DateTime.parse(dateStr);
              final day = _days[date.weekday - 1];
              final period = int.parse(periodStr);
              
              // 과목명 정리
              String clean;
              if ((widget.grade == 2 || widget.grade == 3) && gsheetElectiveSubjects != null) {
                // 2학년, 3학년: 구글 시트의 과목명 사용
                clean = gsheetElectiveSubjects[setNum]?.keys.firstWhere(
                  (name) => subject.contains(name),
                  orElse: () => subject,
                ) ?? subject;
              } else {
                // 구글 시트 데이터가 없는 경우 기존 로직 사용 (하위 호환성)
                clean = _cleanSubject(subject, setNum);
              }
              
              if (clean.isEmpty) continue;
              
              // 같은 과목이 여러 시간에 나타나도 하나의 슬롯으로 통합
              slotsBySet[setNum]!.putIfAbsent(clean, () => ElectiveSlot(
                day: day,
                period: period,
                week: weekIdx == 0 ? '이번주' : '다음주',
                date: date,
                subjects: [clean],
                setNumber: setNum,
                timeSlots: [],
              ));
              
              // 해당 과목의 슬롯에 시간 정보 추가 (중복 방지)
              final slot = slotsBySet[setNum]![clean]!;
              final timeSlotKey = '$day-$period';
              if (!slot.timeSlots.contains(timeSlotKey)) {
                slot.timeSlots.add(timeSlotKey);
              }
            } catch (_) {}
          }
        }
      }

      // 세트별로 정렬하고 선택 번호 부여
      final sortedSlotsBySet = <int, List<ElectiveSlot>>{};
      for (final setNum in targetSetNumbers) {
        final slots = slotsBySet[setNum]?.values.toList() ?? [];
        slots.sort((a, b) {
          final dayDiff = (_dayOrder[a.day] ?? 999) - (_dayOrder[b.day] ?? 999);
          return dayDiff != 0 ? dayDiff : a.period.compareTo(b.period);
        });
        // 각 슬롯에 선택 번호 부여
        for (int i = 0; i < slots.length; i++) {
          slots[i].selectionNumber = i + 1;
        }
        sortedSlotsBySet[setNum] = slots;
      }

      // 2·3학년: 세트별 선택수(requiredCount)만큼 시간표 데이터가 확보되어야 설정 허용
      if ((widget.grade == 2 || widget.grade == 3) &&
          gsheetElectiveSubjects != null &&
          gsheetElectiveSubjects.isNotEmpty) {
        for (final setNum in targetSetNumbers) {
          final requiredCount = _setRequiredCounts[setNum];
          final availableCount = sortedSlotsBySet[setNum]?.length ?? 0;

          // 선택수 정보가 없거나, 필요한 수보다 실제 시간표에서 추출된 선택 슬롯이 부족하면 메인으로 이동
          if (requiredCount == null || requiredCount <= 0) {
            setState(() {
              _isLoading = false;
              _error = null;
              _slotsBySet = {};
            });
            if (mounted) {
              await UserService.instance.setElectiveSetupSkipped(widget.uid);
              if (!widget.isEditMode) {
                await PreferenceManager.instance.setShowElectiveUnavailableMessage(true);
              }
              if (mounted) {
                if (widget.isEditMode) {
                  Navigator.of(context).pop(true);
                } else {
                  Navigator.of(context).pushReplacementNamed('/main');
                }
              }
            }
            return;
          }
          if (availableCount < requiredCount) {
            setState(() {
              _isLoading = false;
              _error = null;
              _slotsBySet = {};
            });
            if (mounted) {
              await UserService.instance.setElectiveSetupSkipped(widget.uid);
              if (!widget.isEditMode) {
                await PreferenceManager.instance.setShowElectiveUnavailableMessage(true);
              }
              if (mounted) {
                if (widget.isEditMode) {
                  Navigator.of(context).pop(true);
                } else {
                  Navigator.of(context).pushReplacementNamed('/main');
                }
              }
            }
            return;
          }
        }
      }

      setState(() {
        _slotsBySet = sortedSlotsBySet;
        _isLoading = false;
      });
      // 2·3학년인데 슬롯이 비어있으면 메인으로 이동
      if (mounted &&
          (widget.grade == 2 || widget.grade == 3) &&
          (sortedSlotsBySet.isEmpty ||
              sortedSlotsBySet.values.every((slots) => slots.isEmpty))) {
        await UserService.instance.setElectiveSetupSkipped(widget.uid);
        if (!widget.isEditMode) {
          await PreferenceManager.instance.setShowElectiveUnavailableMessage(true);
        }
        if (mounted) {
          if (widget.isEditMode) {
            Navigator.of(context).pop(true);
          } else {
            Navigator.of(context).pushReplacementNamed('/main');
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = '시간표 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
        _isLoading = false;
      });
    }
  }

  // 과목이 어느 세트에 속하는지 확인
  int? _getSetNumber(String subject) {
    final allSets = [_set1, _set2, _set3, _set4];
    for (int i = 0; i < allSets.length; i++) {
      if (allSets[i].any((s) => s.isNotEmpty && subject.contains(s))) {
        return i + 1; // 세트 번호는 1부터 시작
      }
    }
    return null;
  }

  // 과목명 정리 (세트 내의 정확한 과목명 반환)
  String _cleanSubject(String subject, int setNumber) {
    final set = [null, _set1, _set2, _set3, _set4][setNumber];
    if (set != null) {
      return set.firstWhere(
        (s) => s.isNotEmpty && subject.contains(s),
        orElse: () => subject,
      );
    }
    return subject;
  }

  // 모든 세트의 과목 리스트 가져오기
  List<String> _getAllSubjectsInSet(int setNumber) {
    // 2,3학년: 구글 시트에서 온 과목 리스트 사용
    if ((widget.grade == 2 || widget.grade == 3) &&
        _sheetSubjectsBySet[setNumber] != null &&
        _sheetSubjectsBySet[setNumber]!.isNotEmpty) {
      return _sheetSubjectsBySet[setNumber]!;
    }

    // (하위 호환용) 시트 데이터가 없을 때만 로컬 상수 사용
    final set = [null, _set1, _set2, _set3, _set4][setNumber];
    return set?.where((s) => s.isNotEmpty).toList() ?? [];
  }

  Future<void> _complete() async {
    // 세트별로 선택 개수 검증 (시트에서 가져온 requiredCount 우선)
    for (final entry in _slotsBySet.entries) {
      final setNum = entry.key;
      final slots = entry.value;
      if (slots.isEmpty) continue;

      final requiredCount =
          _setRequiredCounts[setNum] ?? slots.length; // 기본값: 슬롯 수

      int selectedCount = 0;
      for (var slot in slots) {
        final subjectName =
            slot.subjects.isNotEmpty ? slot.subjects.first : '';
        final key = '${slot.setNumber}-$subjectName';
        if (_selections.containsKey(key)) {
          selectedCount++;
        }
      }

      if (selectedCount != requiredCount) {
        _showSnackBar(
            '세트 $setNum에서 $requiredCount개의 과목을 선택해야 합니다. (현재 $selectedCount개)');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await UserService.instance.saveElectiveSubjects(widget.uid, _selections);
      if (mounted) {
        if (widget.isEditMode) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/main');
          }
        } else {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('선택과목 정보를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final snackBgColor = isDark ? AppColors.darkCard : Colors.white;
    final snackTextColor = isDark ? AppColors.darkText : AppColors.lightText;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: snackBgColor,
        content: Text(
          message,
          style: TextStyle(color: snackTextColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () {
            if (widget.isFromLogin) {
              // 로그인에서 온 경우: 로그인 화면으로
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            } else {
              // 설정에서 온 경우: 이전 화면으로
              Navigator.of(context).pop();
            }
          },
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(textColor)
                : _slotsBySet.isEmpty || _slotsBySet.values.every((slots) => slots.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Center(
                            child: Text(
                              '선택과목 설정',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 50,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildContent(cardColor, textColor, isDark),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildError(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error!,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 16,
              color: textColor,
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 20),
          ElevatedButton(
            onPressed: _loadSlots,
            child: Text(
              '다시 시도',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color cardColor, Color textColor, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: ResponsiveHelper.padding(context, all: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...(_slotsBySet.keys.toList()..sort()).map((setNum) {
                  final slots = _slotsBySet[setNum] ?? [];
                  if (slots.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 세트 헤더
                      Container(
                        padding: ResponsiveHelper.padding(
                          context,
                          vertical: 0,
                          horizontal: 16,
                        ),
                        margin: ResponsiveHelper.padding(context, bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: ResponsiveHelper.borderRadius(context, 8),
                        ),
                        child: Text(
                          _setNames[setNum] ?? '세트 $setNum',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // 세트 내 슬롯들
                      ...slots.map((slot) => _buildSlotCard(slot, cardColor, textColor)),
                      ResponsiveHelper.verticalSpace(context, 8),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        Container(
          padding: ResponsiveHelper.padding(context, all: 20),
          child: SizedBox(
            width: double.infinity,
            height: ResponsiveHelper.height(context, 56),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _complete,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.lightBackground : AppColors.primary,
                foregroundColor: isDark ? AppColors.primary : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: ResponsiveHelper.borderRadius(context, 12),
                ),
                elevation: 4,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: ResponsiveHelper.width(context, 24),
                      height: ResponsiveHelper.height(context, 24),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: ResponsiveHelper.width(context, 2),
                      ),
                    )
                  : Text(
                      '완료',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(ElectiveSlot slot, Color cardColor, Color textColor) {
    // 각 슬롯마다 고유한 키 생성 (세트번호-과목명)
    // 같은 과목이 여러 시간에 나타나도 하나의 선택으로 통합
    final subjectName = slot.subjects.isNotEmpty ? slot.subjects.first : '';
    final key = '${slot.setNumber}-$subjectName';
    final selected = _selections[key];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: ResponsiveHelper.padding(context, bottom: 16),
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: ResponsiveHelper.borderRadius(context, 12),
        border: Border.all(
          color: selected != null
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: selected != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '선택${slot.selectionNumber}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${slot.week} ${slot.day}요일 ${slot.period}교시',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdown(slot, key, cardColor, textColor, isDark, selectedValue: selected),
        ],
      ),
    );
  }

  Widget _buildDropdown(ElectiveSlot slot, String key, Color cardColor, Color textColor, bool isDark, {String? selectedValue}) {
    // 항상 해당 세트의 모든 과목을 선택지로 제공
    final subjects = _getAllSubjectsInSet(slot.setNumber);

    return Theme(
      data: Theme.of(context).copyWith(
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            backgroundColor: WidgetStateProperty.all(cardColor),
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          hintText: '과목을 선택하세요',
          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
          filled: true,
          fillColor: cardColor,
          border: _inputBorder(isDark),
          enabledBorder: _inputBorder(isDark),
          focusedBorder: _inputBorder(isDark),
        ),
        dropdownColor: cardColor,
        style: TextStyle(color: textColor, fontSize: 16),
        items: subjects.map((s) => DropdownMenuItem<String>(
          value: s,
          child: Text(s, style: TextStyle(color: textColor)),
        )).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selections[key] = value);
          } else {
            setState(() => _selections.remove(key));
          }
        },
      ),
    );
  }

  OutlineInputBorder _inputBorder(bool isDark) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color.fromARGB(255, 232, 232, 232) : const Color.fromARGB(255, 40, 40, 40),
      ),
    );
  }
}

class ElectiveSlot {
  final String day; // 첫 번째 발견된 시간 정보 (표시용)
  final int period;
  final String week;
  final DateTime date;
  final List<String> subjects;
  final int setNumber; // 세트 번호 (1-4)
  int selectionNumber; // 세트 내 선택 번호 (1, 2, 3...)
  final List<String> timeSlots; // 해당 과목이 나타나는 모든 시간대 (예: ['월-3', '화-5'])

  ElectiveSlot({
    required this.day,
    required this.period,
    required this.week,
    required this.date,
    required this.subjects,
    required this.setNumber,
    this.selectionNumber = 0,
    required this.timeSlots,
  });
}

