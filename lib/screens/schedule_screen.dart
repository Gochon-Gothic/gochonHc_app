import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme_colors.dart';
import '../theme_provider.dart';
import '../utils/shadows.dart';
import '../utils/responsive_helper.dart';

class ScheduleView extends StatefulWidget {
  final VoidCallback onExit;

  const ScheduleView({super.key, required this.onExit});

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  late final PageController _monthController;
  final ScrollController _tabsScrollController = ScrollController();
  int _year = DateTime.now().year;
  int _currentMonthIndex = DateTime.now().month - 1; // 0..11
  bool _isLoading = true;
  String? _error;
  Map<String, List<String>> _scheduleMap = {}; // 'yyyy-MM-dd': [events]
  int? _selectedDay;
  final ScrollController _listController = ScrollController();
  final Map<int, GlobalKey> _dayItemKeys = {};

  int get _totalMonths {
    final now = DateTime.now();
    if (now.month == 12 && _year == now.year) {
      return 15;
    }
    return 12;
  }
  
  // 현재 인덱스에 해당하는 실제 년도와 월 반환
  Map<String, int> _getYearAndMonth(int index) {
    if (index < 12) {
      return {'year': _year, 'month': index + 1};
    } else {
      return {'year': _year + 1, 'month': index - 11};
    }
  }

  @override
  void initState() {
    super.initState();
    // 현재 날짜 확인
    final now = DateTime.now();
    _year = now.year;
    _currentMonthIndex = now.month - 1; // 0~11
    
    // 현재 월이 1월이고 이전에 12월이었던 경우를 대비해 년도 확인
    // (실제로는 현재 날짜 기준으로 자동 처리됨)
    _monthController = PageController(initialPage: _currentMonthIndex);
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 현재 년도 데이터 가져오기
      final from = '${_year}0101';
      final to = '${_year}1231';
      final url =
          'https://open.neis.go.kr/hub/SchoolSchedule?KEY=44e1ba05c56746c5a09a5fbd5eead0be&Type=json&pIndex=1&pSize=365&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7531375&AA_FROM_YMD=$from&AA_TO_YMD=$to';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      final Map<String, List<String>> map = {};
      
      if (data['SchoolSchedule'] != null) {
        final rows = data['SchoolSchedule'][1]['row'] as List;
        for (var row in rows) {
          final date = row['AA_YMD'] as String;
          final event = row['EVENT_NM'] as String;
          final ymd = '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
          map.putIfAbsent(ymd, () => []).add(event);
        }
      }
      
      // 현재 날짜가 12월이고 현재 년도와 일치하면 다음 년도 1,2,3월 데이터도 가져오기
      final now = DateTime.now();
      if (now.month == 12 && _year == now.year) {
        final nextYear = _year + 1;
        final nextFrom = '${nextYear}0101';
        final nextTo = '${nextYear}0331';
        final nextUrl =
            'https://open.neis.go.kr/hub/SchoolSchedule?KEY=44e1ba05c56746c5a09a5fbd5eead0be&Type=json&pIndex=1&pSize=365&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7531375&AA_FROM_YMD=$nextFrom&AA_TO_YMD=$nextTo';
        try {
          final nextResponse = await http.get(Uri.parse(nextUrl));
          final nextData = json.decode(nextResponse.body);
          if (nextData['SchoolSchedule'] != null) {
            final nextRows = nextData['SchoolSchedule'][1]['row'] as List;
            for (var row in nextRows) {
              final date = row['AA_YMD'] as String;
              final event = row['EVENT_NM'] as String;
              final ymd = '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
              map.putIfAbsent(ymd, () => []).add(event);
            }
          }
        } catch (e) {
          // 다음 년도 데이터 가져오기 실패해도 현재 년도 데이터는 표시
          print('다음 년도 학사일정 로드 실패: $e');
        }
      }
      
      final Map<String, List<String>> filtered = {};
      map.forEach((k, v) {
        final f = v.where((e) => !e.contains('방학') && !e.contains('토요휴업일')).toList();
        if (f.isNotEmpty) filtered[k] = f;
      });
      setState(() {
        _scheduleMap = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final yearMonth = _getYearAndMonth(_currentMonthIndex);
    final month = yearMonth['month']!;
    final year = yearMonth['year']!;
    final List<_DayEvents> monthlyEvents = _collectMonthlyEvents(year, month);

    return Container(
      color: bgColor,
      width: double.infinity,
      child: Column(
        children: [
          ResponsiveHelper.verticalSpace(context, 65),
          Padding(
            padding: ResponsiveHelper.padding(
              context,
              left: 20,
              right: 30,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onExit,
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: textColor,
                    size: ResponsiveHelper.width(context, 24),
                ),
                ),
                ResponsiveHelper.horizontalSpace(context, 1),
                Text(
                  '학사일정',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 30,
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    height: 1,
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
          ResponsiveHelper.verticalSpace(context, 33),
          _MonthTabsScrollable(
            controller: _monthController,
            scrollController: _tabsScrollController,
            currentIndex: _currentMonthIndex,
            totalMonths: _totalMonths, // 12월이면 15, 아니면 12
            currentYear: _year,
            onIndexChanged: (i, deltaYear) {
              setState(() {
                // 인덱스 12~14는 다음 년도 1~3월이지만 연도 전환하지 않고 그냥 인덱스만 유지
                if (i >= 12) {
                  // 다음 년도 1,2,3월을 선택했지만 연도 전환하지 않고 인덱스만 유지
                  _currentMonthIndex = i;
                } else {
                  // 현재 년도의 월
                  if (deltaYear != 0) {
                    _year += deltaYear;
                  }
                  _currentMonthIndex = i;
                }
                _selectedDay = null;
              });
              
              // 년도가 변경되었을 때만 데이터 다시 가져오기
              if (deltaYear != 0) {
                _fetchSchedules();
              }
            },
          ),
          ResponsiveHelper.verticalSpace(context, 2),
          _WeekdaysRow(textColor: textColor),
          ResponsiveHelper.verticalSpace(context, 0),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: ResponsiveHelper.height(context, 400),
              ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                        )
                    : PageView.builder(
                        controller: _monthController,
                        onPageChanged: (i) {
                          // 인덱스 12~14는 다음 년도 1~3월이지만 연도 전환하지 않고 그냥 인덱스만 유지
                          setState(() {
                            _currentMonthIndex = i;
                            _selectedDay = null;
                          });
                        },
                        itemCount: _totalMonths,
                        itemBuilder: (context, index) {
                          final yearMonth = _getYearAndMonth(index);
                          final month = yearMonth['month']!;
                          final year = yearMonth['year']!;
                          return _MonthGrid(
                            year: year,
                            month: month,
                            scheduleMap: _scheduleMap,
                            selectedDay: _selectedDay,
                            onDaySelected: (d) {
                              setState(() => _selectedDay = d);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToDay(d);
                              });
                            },
                          );
                        },
                        ),
                      ),
          ),
          SizedBox(
            height: ResponsiveHelper.height(context, 300),
            child: Padding(
              padding: ResponsiveHelper.padding(
                context,
                left: 20,
                right: 20,
                top: 50,
                bottom: 80,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: ResponsiveHelper.borderRadius(context, 16),
                  boxShadow: AppShadows.card(isDark),
                ),
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: 16,
                  vertical: 12,
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    return true;
                  },
                  child: ListView.builder(
                    controller: _listController,
                    padding: EdgeInsets.zero,
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    itemCount: monthlyEvents.length,
                    itemBuilder: (context, idx) {
                      final e = monthlyEvents[idx];
                      final key = _dayItemKeys.putIfAbsent(e.day, () => GlobalKey());
                      return Container(
                        key: key,
                        margin: ResponsiveHelper.padding(context, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$month월 ${e.day}일',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 16,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ResponsiveHelper.verticalSpace(context, 6),
                            Text(
                              e.events.join(', '),
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 14,
                                color: textColor,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          ResponsiveHelper.verticalSpace(context, 24),
        ],
      ),
    );
  }

  List<_DayEvents> _collectMonthlyEvents(int year, int month) {
    final Map<int, List<String>> dayToEvents = {};
    _scheduleMap.forEach((date, events) {
      final parts = date.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      if (y == year && m == month) {
        dayToEvents.putIfAbsent(d, () => []).addAll(events);
      }
    });
    final days = dayToEvents.keys.toList()..sort();
    return days.map((d) => _DayEvents(day: d, events: dayToEvents[d]!.toList())).toList();
  }

  void _scrollToDay(int day) {
    if (!_listController.hasClients) return;
    
    final month = _currentMonthIndex + 1;
    final monthlyEvents = _collectMonthlyEvents(_year, month);
    final index = monthlyEvents.indexWhere((e) => e.day == day);
    
    if (index == -1) return;
    const double itemHeight = 51.0;
    final double targetOffset = index * itemHeight;
    
    _listController.animateTo(
      targetOffset.clamp(0.0, _listController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }
}


class _MonthTabsScrollable extends StatelessWidget {
  final PageController controller;
  final ScrollController scrollController;
  final int currentIndex;
  final int totalMonths;
  final int currentYear;
  final void Function(int newIndex, int deltaYear) onIndexChanged;

  const _MonthTabsScrollable({
    required this.controller,
    required this.scrollController,
    required this.currentIndex,
    required this.totalMonths,
    required this.currentYear,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double barHeight = 40;
    const double capsuleWidth = 40;
    const double capsuleHeight = 28;
    const double horizontalPadding = 16;

    return SizedBox(
      height: barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double fullWidth = constraints.maxWidth;
          final double innerWidth = fullWidth - horizontalPadding * 2;
          final double itemWidth = innerWidth / 7; // 7칸 가시

          WidgetsBinding.instance.addPostFrameCallback((_) {
            int scrollOffset = (currentIndex - 3).clamp(0, (totalMonths - 4).clamp(0, double.infinity).toInt());
            final double target = scrollOffset * itemWidth;
            if (scrollController.hasClients) {
              final double diff = (scrollController.offset - target).abs();
              if (diff > 6.0) {
                scrollController.animateTo(
                  target,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              }
            }
          });

          return Stack(
            children: [
              // 라벨 리스트 (동적 개월 수)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: ListView.builder(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: totalMonths,
                    itemBuilder: (context, i) {
                      final selected = i == currentIndex;
                      String label;
                      if (i < 12) {
                        label = '${i + 1}월';
                      } else {
                        label = '${i - 11}월';
                      }
                      final Color textColor = selected
                          ? const Color.fromRGBO(255, 197, 30, 1)
                          : (isDark
                              ? const Color.fromRGBO(230, 230, 230, 0.85)
                              : const Color.fromRGBO(48, 48, 46, 0.85));
                      return SizedBox(
                        width: itemWidth,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              if (controller.hasClients) {
                                controller.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.ease);
                              }
                              onIndexChanged(i, 0);
                            },
                            child: Text(
                              label,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  double page = currentIndex.toDouble();
                  if (controller.positions.isNotEmpty) {
                    final p = controller.page;
                    if (p != null) {
                      page = p.clamp(0, (totalMonths - 1).toDouble());
                    }
                  }
                  
                  int scrollBase;
                  if (totalMonths == 15 && currentIndex >= 12) {
                    scrollBase = (currentIndex - 3).clamp(0, totalMonths - 4);
                  } else {
                    scrollBase = (currentIndex - 3).clamp(0, (totalMonths - 4).clamp(0, double.infinity).toInt());
                  }
                  
                  double localIndex = (page - scrollBase).clamp(0, 6);
                  
                  if (totalMonths == 15 && currentIndex >= 12) {
                    localIndex = 4.0 + (currentIndex - 12);
                  }
                  
                  final double centerX = horizontalPadding + (itemWidth * 0.5) + localIndex * itemWidth;
                  final double leftForCapsule = centerX - (capsuleWidth / 2);
                  final Color capsuleFill = isDark ? const Color.fromRGBO(255, 255, 255, 0.12) : const Color.fromRGBO(0, 0, 0, 0.08);

                  return Positioned(
                    left: leftForCapsule,
                    top: (barHeight - capsuleHeight) / 2,
                    width: capsuleWidth,
                    height: capsuleHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: capsuleFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.35), width: 1),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayEvents {
  final int day;
  final List<String> events;
  _DayEvents({required this.day, required this.events});
}
class _WeekdaysRow extends StatelessWidget {
  final Color textColor;

  const _WeekdaysRow({required this.textColor});

  @override
  Widget build(BuildContext context) {
    final labels = const ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          Color c = textColor;
          if (i == 0) c = const Color.fromRGBO(236, 69, 69, 1); // 일
          if (i == 6) c = const Color.fromARGB(255, 203, 204, 208); // 토
          return SizedBox(
            width: 32,
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  color: c,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, List<String>> scheduleMap;
  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.scheduleMap,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    // 일(0)~토(6) 기준 시작 요일
    final startWeekday = firstDay.weekday % 7;

    // 연속 일정 분석
    final continuousEvents = _analyzeContinuousEvents();

    List<Widget> cells = [];
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final events = scheduleMap[dateStr] ?? const <String>[];
      final hasEvent = events.isNotEmpty;
      final firstEvent = hasEvent ? events.first : null;
      final isToday = today.year == year && today.month == month && today.day == d;
      final isSelected = selectedDay == d;

      // 연속 일정 정보 확인
      final continuousInfo = continuousEvents[d];

      cells.add(
        GestureDetector(
          onTap: () => onDaySelected(d),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 3), // 상단 여백 더 줄임 (4 -> 3)
              Container(
                width: 32,
                height: 32,
                decoration: isToday
                    ? const BoxDecoration(color: Color(0xFFFFC51D), shape: BoxShape.circle)
                    : isSelected
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFC51D), width: 2),
                          )
                        : null,
                child: Center(
                  child: Text(
                    '$d',
                    style: TextStyle(
                      color: isToday ? Colors.black : (isDark ? Colors.white : Colors.black),
                      fontWeight: hasEvent ? FontWeight.w600 : (isToday || isSelected ? FontWeight.bold : FontWeight.normal),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1), // 날짜와 캡슐 사이 간격 유지
              if (continuousInfo == null && firstEvent != null)
                _DayCapsule(
                  text: firstEvent,
                  isDark: isDark,
                ),
            ],
          ),
        ),
      );
    }

    final eventRanges = _analyzeEventRanges();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          // 연속 이벤트를 한 줄 캡슐로 오버레이 (합쳐진 폭 중앙 정렬)
          ...eventRanges.map((range) => _buildRangeBackground(range, isDark, startWeekday)),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 1, // 행 간격 더 줄임 (2 -> 1)
            crossAxisSpacing: 0,
            childAspectRatio: 0.95, // 셀 높이 조정 (0.9 -> 0.95)
            padding: const EdgeInsets.only(top: 4, bottom: 2), // 하단 패딩 더 줄임 (4 -> 2)
            children: cells,
          ),
        ],
      ),
    );
  }

  Map<int, _ContinuousEventInfo> _analyzeContinuousEvents() {
    final Map<int, _ContinuousEventInfo> result = {};
    final Map<String, List<int>> eventToDays = {};

    // 각 이벤트별로 날짜 리스트 수집
    for (int d = 1; d <= DateTime(year, month + 1, 0).day; d++) {
      final dateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final events = scheduleMap[dateStr] ?? const <String>[];
      for (final event in events) {
        eventToDays.putIfAbsent(event, () => []).add(d);
      }
    }

    // 연속된 날짜 범위 찾기 (2일 이상)
    eventToDays.forEach((eventName, days) {
      if (days.length < 2) return;
      days.sort();
      
      List<List<int>> ranges = [];
      List<int> currentRange = [days.first];
      
      for (int i = 1; i < days.length; i++) {
        if (days[i] == days[i-1] + 1) {
          currentRange.add(days[i]);
        } else {
          if (currentRange.length >= 2) ranges.add(List.from(currentRange));
          currentRange = [days[i]];
        }
      }
      if (currentRange.length >= 2) ranges.add(currentRange);
      
      // 각 범위에 대해 위치 정보 설정
      for (final range in ranges) {
        for (int i = 0; i < range.length; i++) {
          final day = range[i];
          _CapsulePosition position;
          if (i == 0) {
            position = range.length == 1 ? _CapsulePosition.single : _CapsulePosition.start;
          } else if (i == range.length - 1) {
            position = _CapsulePosition.end;
          } else {
            position = _CapsulePosition.middle;
          }
          
          result[day] = _ContinuousEventInfo(
            eventName: eventName,
            position: position,
          );
        }
      }
    });

    return result;
  }

  List<_EventRange> _analyzeEventRanges() {
    final Map<String, List<int>> eventToDays = {};
    final daysInMonth = DateTime(year, month + 1, 0).day;

    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final events = scheduleMap[dateStr] ?? const <String>[];
      for (final event in events) {
        eventToDays.putIfAbsent(event, () => []).add(d);
      }
    }

    List<_EventRange> ranges = [];
    eventToDays.forEach((eventName, days) {
      if (days.length < 2) return;
      days.sort();

      List<int> current = [days.first];
      for (int i = 1; i < days.length; i++) {
        if (days[i] == days[i - 1] + 1) {
          current.add(days[i]);
        } else {
          if (current.length >= 2) {
            ranges.add(_EventRange(eventName: eventName, days: List.from(current)));
          }
          current = [days[i]];
        }
      }
      if (current.length >= 2) {
        ranges.add(_EventRange(eventName: eventName, days: current));
      }
    });

    return ranges;
  }

  Widget _buildRangeBackground(_EventRange range, bool isDark, int startWeekday) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gridWidth = constraints.maxWidth;
        const int columns = 7;
        const double crossAxisSpacing = 0;
        const double mainAxisSpacing = 1; // GridView의 mainAxisSpacing과 일치 (2 -> 1)
        const double aspect = 0.95; // GridView의 childAspectRatio와 일치 (0.9 -> 0.95)
        const double gridTopPadding = 4; // GridView의 padding top과 일치
        final double cellWidth = (gridWidth - (columns - 1) * crossAxisSpacing) / columns;
        final double cellHeight = cellWidth / aspect;

        // 날짜 아래 일정이 시작되는 위치 계산 (셀 내부 오프셋만)
        // 날짜 위쪽 여백(3) + 날짜 컨테이너 높이(32) + 날짜와 캡슐 사이 여백(1) = 36
        // 실제 측정값에 맞게 조정
        const double dateTopOffset = 3 + 32 + 1;

        final firstDay = range.days.first;
        final lastDay = range.days.last;
        final firstGridIndex = startWeekday + firstDay - 1;
        final lastGridIndex = startWeekday + lastDay - 1;
        final firstRow = firstGridIndex ~/ columns;
        final firstCol = firstGridIndex % columns;
        final lastRow = lastGridIndex ~/ columns;
        final lastCol = lastGridIndex % columns;

        List<Widget> bars = [];
        for (int row = firstRow; row <= lastRow; row++) {
          final int startCol = (row == firstRow) ? firstCol : 0;
          final int endCol = (row == lastRow) ? lastCol : columns - 1;
          final double left = startCol * (cellWidth + crossAxisSpacing);
          final double top = gridTopPadding + row * (cellHeight + mainAxisSpacing) + dateTopOffset;
          final double width = (endCol - startCol + 1) * cellWidth + (endCol - startCol) * crossAxisSpacing;

          bars.add(Positioned(
            left: left,
            top: top,
            width: width,
            height: 14,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color.fromRGBO(255, 255, 255, 0.12) : const Color.fromRGBO(0, 0, 0, 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.35), width: 0.5),
              ),
              alignment: Alignment.center,
              child: (row == firstRow)
                  ? Text(
                      range.eventName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 8, height: 1.0),
                    )
                  : null,
            ),
          ));
        }

        return Stack(children: bars);
      },
    );
  }
}

class _DayCapsule extends StatelessWidget {
  final String text;
  final bool isDark;
  const _DayCapsule({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? const Color.fromRGBO(255, 255, 255, 0.12)
            : const Color.fromRGBO(0, 0, 0, 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 8,
          height: 1.0,
        ),
      ),
    );
  }
}

enum _CapsulePosition { start, middle, end, single }

class _ContinuousEventInfo {
  final String eventName;
  final _CapsulePosition position;
  _ContinuousEventInfo({required this.eventName, required this.position});
}
class _EventRange {
  final String eventName;
  final List<int> days;
  _EventRange({required this.eventName, required this.days});
}
