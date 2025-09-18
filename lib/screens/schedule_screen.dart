import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme_colors.dart';
import '../theme_provider.dart';
import '../utils/shadows.dart';

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

  @override
  void initState() {
    super.initState();
    _monthController = PageController(initialPage: _currentMonthIndex);
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final from = '${_year}0101';
      final to = '${_year}1231';
      final url =
          'https://open.neis.go.kr/hub/SchoolSchedule?KEY=44e1ba05c56746c5a09a5fbd5eead0be&Type=json&pIndex=1&pSize=365&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7531375&AA_FROM_YMD=$from&AA_TO_YMD=$to';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['SchoolSchedule'] != null) {
        final rows = data['SchoolSchedule'][1]['row'] as List;
        final Map<String, List<String>> map = {};
        for (var row in rows) {
          final date = row['AA_YMD'] as String;
          final event = row['EVENT_NM'] as String;
          final ymd = '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
          map.putIfAbsent(ymd, () => []).add(event);
        }
        final Map<String, List<String>> filtered = {};
        map.forEach((k, v) {
          final f = v.where((e) => !e.contains('겨울방학') && !e.contains('여름방학') && !e.contains('토요휴업일')).toList();
          if (f.isNotEmpty) filtered[k] = f;
        });
        setState(() {
          _scheduleMap = filtered;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '학사일정을 불러오지 못했습니다.';
          _isLoading = false;
        });
      }
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
    final month = _currentMonthIndex + 1;
    final List<_DayEvents> monthlyEvents = _collectMonthlyEvents(_year, month);

    return Container(
      color: bgColor,
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 65),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 30),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onExit,
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                ),
                const SizedBox(width: 1),
                Text(
                  '학사일정',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
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
          const SizedBox(height: 33),
          _MonthTabsScrollable(
            controller: _monthController,
            scrollController: _tabsScrollController,
            currentIndex: _currentMonthIndex,
            onIndexChanged: (i, deltaYear) {
              setState(() {
                if (deltaYear != 0) {
                  _year += deltaYear;
                }
                _currentMonthIndex = i;
                _selectedDay = null;
              });
              if (deltaYear != 0) {
                _fetchSchedules();
              }
            },
          ),
          const SizedBox(height: 2),
          _WeekdaysRow(textColor: textColor),
          const SizedBox(height: 0),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: textColor)))
                    : PageView.builder(
                        controller: _monthController,
                        onPageChanged: (i) {
                          int deltaYear = 0;
                          // 컨트롤러의 이전 인덱스와 비교할 수 없어 현재-기준으로 판단
                          if (_currentMonthIndex == 11 && i == 0) deltaYear = 1;
                          if (_currentMonthIndex == 0 && i == 11) deltaYear = -1;
                          setState(() {
                            if (deltaYear != 0) {
                              _year += deltaYear;
                            }
                            _currentMonthIndex = i;
                            _selectedDay = null;
                          });
                          if (deltaYear != 0) {
                            _fetchSchedules();
                          }
                        },
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          return _MonthGrid(
                            year: _year,
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
          SizedBox(
            height: 300,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 80),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card(isDark),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$month월 ${e.day}일',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.events.join(', '),
                            style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
    final key = _dayItemKeys[day];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        alignment: 0.1,
      );
    }
  }
}


class _MonthTabsScrollable extends StatelessWidget {
  final PageController controller;
  final ScrollController scrollController;
  final int currentIndex;
  final void Function(int newIndex, int deltaYear) onIndexChanged;

  const _MonthTabsScrollable({
    required this.controller,
    required this.scrollController,
    required this.currentIndex,
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

          // 현재 인덱스를 중앙 근처로 스크롤
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final double target = ((currentIndex - 3).clamp(0, 5)) * itemWidth;
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
              // 라벨 리스트 (12개월)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: ListView.builder(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: 12,
                    itemBuilder: (context, i) {
                      final selected = i == currentIndex;
                      final label = '${i + 1}월';
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
                              int deltaYear = 0;
                              // 현재 year 테두리에서 이전/다음 해로 자연스럽게 전이
                              if (currentIndex == 11 && i == 0) deltaYear = 1;
                              if (currentIndex == 0 && i == 11) deltaYear = -1;
                              if (controller.hasClients) {
                                controller.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.ease);
                              }
                              onIndexChanged(i, deltaYear);
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
                      // 스크롤 중에도 실시간으로 page 따라가게 함
                      page = p.clamp(0, 11);
                    }
                  }
                  final double localIndex = (page - (currentIndex - 3).clamp(0, 5)).clamp(0, 6);
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
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
              const SizedBox(height: 2),
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
            mainAxisSpacing: 1,
            crossAxisSpacing: 0,
            childAspectRatio: 0.75,
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
        const double mainAxisSpacing = 1;
        const double aspect = 0.75;
        final double cellWidth = (gridWidth - (columns - 1) * crossAxisSpacing) / columns;
        final double cellHeight = cellWidth / aspect;

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
          final double top = row * (cellHeight + mainAxisSpacing) + 93; // 숫자(32)+간격(2)
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
