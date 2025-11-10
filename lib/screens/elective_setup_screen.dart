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

  const ElectiveSetupScreen({
    super.key,
    required this.userEmail,
    required this.uid,
    required this.grade,
    required this.classNum,
  });

  @override
  State<ElectiveSetupScreen> createState() => _ElectiveSetupScreenState();
}

class _ElectiveSetupScreenState extends State<ElectiveSetupScreen> {
  bool _isLoading = true;
  List<ElectiveSlot> _slots = [];
  final Map<String, String> _selections = {};
  String? _error;

  static const _apiKey = '2cf24c119b434f93b2f916280097454a';
  static const _eduOfficeCode = 'J10';
  static const _schoolCode = '7531375';
  static const _subjects = ['지구과학Ⅰ', '지구과학Ⅱ', '물리학Ⅱ', '물리학Ⅰ'];
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

      final slotMap = <String, ElectiveSlot>{};

      for (int weekIdx = 0; weekIdx < responses.length; weekIdx++) {
        final data = responses[weekIdx].data;
        final rows = data?['hisTimetable']?[1]?['row'] as List?;
        
        if (rows == null) continue;

        for (var item in rows) {
          final subject = (item['ITRT_CNTNT'] as String? ?? '').trim();
          final dateStr = item['ALL_TI_YMD'] as String? ?? '';
          final periodStr = item['PERIO'] as String? ?? '';

          if (!_isElective(subject) || dateStr.isEmpty || periodStr.isEmpty) {
            continue;
          }

          try {
            final date = DateTime.parse(dateStr);
            final day = _days[date.weekday - 1];
            final period = int.parse(periodStr);
            final key = '$day-$period';

            slotMap.putIfAbsent(key, () => ElectiveSlot(
              day: day,
              period: period,
              week: weekIdx == 0 ? '이번주' : '다음주',
              date: date,
              subjects: [],
            ));

            final clean = _cleanSubject(subject);
            if (clean.isNotEmpty && !slotMap[key]!.subjects.contains(clean)) {
              slotMap[key]!.subjects.add(clean);
            }
          } catch (e) {
            print('Parse error: $e');
          }
        }
      }

      setState(() {
        _slots = slotMap.values.toList()
          ..sort((a, b) {
            final dayDiff = (_dayOrder[a.day] ?? 999) - (_dayOrder[b.day] ?? 999);
            return dayDiff != 0 ? dayDiff : a.period.compareTo(b.period);
          });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '시간표 불러오기 실패: $e';
        _isLoading = false;
      });
    }
  }

  bool _isElective(String subject) {
    return _subjects.any((s) => subject.contains(s));
  }

  String _cleanSubject(String subject) {
    return _subjects.firstWhere(
      (s) => subject.contains(s),
      orElse: () => subject,
    );
  }

  Future<void> _complete() async {
    if (_slots.length != _selections.length) {
      _showSnackBar('모든 선택과목을 선택해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await UserService.instance.saveElectiveSubjects(widget.uid, _selections);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
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
                : _slots.isEmpty
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
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ..._slots.map((slot) => _buildSlotCard(slot, cardColor, textColor)),
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
    final key = '${slot.day}-${slot.period}';
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
          Text(
            '${slot.week} ${slot.day}요일 ${slot.period}교시',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          selected != null
              ? _buildSelectedSubject(selected, key)
              : _buildDropdown(slot, key, cardColor, textColor, isDark),
        ],
      ),
    );
  }

  Widget _buildSelectedSubject(String subject, String key) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            subject,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.primary,
            onPressed: () => setState(() => _selections.remove(key)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(ElectiveSlot slot, String key, Color cardColor, Color textColor, bool isDark) {
    final subjects = slot.subjects.isNotEmpty ? slot.subjects : List.from(_subjects);

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        hintText: '과목을 선택하세요',
        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
        filled: true,
        fillColor: cardColor,
        border: _inputBorder(isDark),
        enabledBorder: _inputBorder(isDark),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      style: TextStyle(color: textColor, fontSize: 16),
      items: subjects.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selections[key] = value);
      },
    );
  }

  OutlineInputBorder _inputBorder(bool isDark) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    );
  }
}

class ElectiveSlot {
  final String day;
  final int period;
  final String week;
  final DateTime date;
  final List<String> subjects;

  ElectiveSlot({
    required this.day,
    required this.period,
    required this.week,
    required this.date,
    required this.subjects,
  });
}

