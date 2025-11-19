import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/user_service.dart';
import '../theme_colors.dart';

class ElectiveSetupScreen extends StatefulWidget {
  final String userEmail;
  final String uid;
  final int grade;
  final int classNum;
  final bool isEditMode; 

  const ElectiveSetupScreen({
    super.key,
    required this.userEmail,
    required this.uid,
    required this.grade,
    required this.classNum,
    this.isEditMode = false,
  });

  @override
  State<ElectiveSetupScreen> createState() => _ElectiveSetupScreenState();
}

class _ElectiveSetupScreenState extends State<ElectiveSetupScreen> {
  bool _isLoading = true;
  Map<int, List<ElectiveSlot>> _slotsBySet = {}; // 세트별로 그룹화된 슬롯
  final Map<String, String> _selections = {}; // key: 'set-slotKey', value: 선택한 과목
  String? _error;

  static const _apiKey = '2cf24c119b434f93b2f916280097454a';
  static const _eduOfficeCode = 'J10';
  static const _schoolCode = '7531375';
  //1~4는 2학년, 5~8은 3학년
  //세트1은 ABC선택 말하는거, 세트2는 음미, 세트3은 언어, 세트4는 기하,고전등
  //세트5는 
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

    try {
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
      // 같은 과목이 여러 시간에 나타나도 하나의 슬롯으로 통합
      final slotsBySet = <int, Map<String, ElectiveSlot>>{};

      // 세트 1부터 4까지 순서대로 검색
      for (int setNum = 1; setNum <= 4; setNum++) {
        slotsBySet[setNum] = {};

        for (int weekIdx = 0; weekIdx < responses.length; weekIdx++) {
          final data = responses[weekIdx].data;
          final rows = data?['hisTimetable']?[1]?['row'] as List?;
          
          if (rows == null) continue;

          for (var item in rows) {
            final subject = (item['ITRT_CNTNT'] as String? ?? '').trim();
            final dateStr = item['ALL_TI_YMD'] as String? ?? '';
            final periodStr = item['PERIO'] as String? ?? '';
            final subjectSetNum = _getSetNumber(subject);
            if (subjectSetNum != setNum || dateStr.isEmpty || periodStr.isEmpty) {
              continue;
            }

            try {
              final date = DateTime.parse(dateStr);
              final day = _days[date.weekday - 1];
              final period = int.parse(periodStr);
              
              // 과목명으로 키 생성 (같은 과목은 하나의 슬롯으로 통합)
              final clean = _cleanSubject(subject, setNum);
              if (clean.isEmpty) continue;
              
              // 같은 과목이 여러 시간에 나타나도 하나의 슬롯으로 통합
              slotsBySet[setNum]!.putIfAbsent(clean, () => ElectiveSlot(
                day: day, // 첫 번째 발견된 시간 정보 저장
                period: period,
                week: weekIdx == 0 ? '이번주' : '다음주',
                date: date,
                subjects: [clean],
                setNumber: setNum,
                timeSlots: [], // 여러 시간 정보를 저장할 리스트
              ));
              
              // 해당 과목의 슬롯에 시간 정보 추가 (중복 방지)
              final slot = slotsBySet[setNum]![clean]!;
              final timeSlotKey = '$day-$period';
              if (!slot.timeSlots.contains(timeSlotKey)) {
                slot.timeSlots.add(timeSlotKey);
              }
            } catch (e) {
              print('Parse error: $e');
            }
          }
        }
      }

      // 세트별로 정렬하고 선택 번호 부여
      final sortedSlotsBySet = <int, List<ElectiveSlot>>{};
      for (int setNum = 1; setNum <= 4; setNum++) {
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

      setState(() {
        _slotsBySet = sortedSlotsBySet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '시간표 불러오기 실패: $e';
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
    final set = [null, _set1, _set2, _set3, _set4][setNumber];
    return set?.where((s) => s.isNotEmpty).toList() ?? [];
  }

  Future<void> _complete() async {
    // 모든 세트의 모든 슬롯이 선택되었는지 확인
    int totalSlots = 0;
    int selectedSlots = 0;
    for (var slots in _slotsBySet.values) {
      totalSlots += slots.length;
      for (var slot in slots) {
        final subjectName = slot.subjects.isNotEmpty ? slot.subjects.first : '';
        final key = '${slot.setNumber}-$subjectName';
        if (_selections.containsKey(key)) {
          selectedSlots++;
        }
      }
    }

    if (totalSlots != selectedSlots) {
      _showSnackBar('모든 선택과목을 선택해주세요.');
      return;
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
        _showSnackBar('저장 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          '선택과목 선택',
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(textColor)
                : _slotsBySet.isEmpty || _slotsBySet.values.every((slots) => slots.isEmpty)
                    ? Center(child: Text('선택과목이 없습니다.', style: TextStyle(color: textColor)))
                    : _buildContent(cardColor, textColor, isDark),
      ),
    );
  }

  Widget _buildError(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: TextStyle(color: textColor)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _loadSlots, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  Widget _buildContent(Color cardColor, Color textColor, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이동 수업 과목을 선택해주세요',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 세트별로 섹션 나누어 표시
                ...List.generate(4, (index) {
                  final setNum = index + 1;
                  final slots = _slotsBySet[setNum] ?? [];
                  if (slots.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 세트 헤더
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '세트 $setNum',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // 세트 내 슬롯들
                      ...slots.map((slot) => _buildSlotCard(slot, cardColor, textColor)),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _complete,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.lightBackground : AppColors.primary,
                foregroundColor: isDark ? AppColors.primary : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )

                  : const Text('완료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
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

