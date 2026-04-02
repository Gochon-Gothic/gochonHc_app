import 'dart:convert';

import 'package:flutter/material.dart';

/// 학사일정: ScheduleView(PageView 월별, 일별 이벤트) + onExit으로 홈 복귀
///
/// [로직 흐름]
/// 1. _fetchSchedules: PreferenceManager.getScheduleCache → 3/2·9/1이면 null
/// 2. 캐시 없으면 NEIS SchoolSchedule API → 토요휴업·방학 제외 → setScheduleCache
/// 3. PageView로 월별 스와이프, _scheduleMap['yyyy-MM-dd']로 이벤트 표시
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme_colors.dart';
import '../theme_provider.dart';
import '../utils/shadows.dart';
import '../utils/responsive_helper.dart';
import '../utils/preference_manager.dart';

String _scheduleYmdKey(int year, int month, int day) {
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

List<List<int>> _subRangesExcludingPersonal(
  List<int> consecutiveSorted,
  Set<int> personalDays,
) {
  final List<List<int>> out = [];
  List<int> cur = [];
  for (final d in consecutiveSorted) {
    if (personalDays.contains(d)) {
      if (cur.length >= 2) out.add(List.from(cur));
      cur = [];
    } else {
      cur.add(d);
    }
  }
  if (cur.length >= 2) out.add(cur);
  return out;
}

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
  Map<String, List<String>> _personalScheduleMap = {};
  int? _selectedDay;
  final ScrollController _listController = ScrollController();
  final Map<int, GlobalKey> _dayItemKeys = {};

  /// 캘린더 하단을 버튼·카드가 덮는 높이(px).
  static const double _calendarFloatOverlap = 50;

  /// 겹침 구간만큼 그리드 아래 스크롤 여백 — 말일 행을 가시 영역으로 올릴 수 있게 함(겹친 줄은 스크롤로 '끝'에서 숨김 처리).
  static const double _calendarScrollBottomPad = 12;

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

  int _defaultDayForMonthIndex(int monthIndex) {
    final ym = _getYearAndMonth(monthIndex);
    final y = ym['year']!;
    final m = ym['month']!;
    final now = DateTime.now();
    if (y == now.year && m == now.month) {
      final daysInMonth = DateTime(y, m + 1, 0).day;
      return now.day.clamp(1, daysInMonth);
    }
    return 1;
  }

  /// _MonthGrid와 동일한 그리드 규칙(6행 기준)으로 PageView 높이를 맞춤
  double _calendarPageHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const gridHorizontalInset = 40.0;
    const columns = 7;
    const mainAxisSpacing = 1.0;
    const aspect = 0.95;
    const gridPaddingVertical = 4.0 + 2.0;
    const rowCount = 6;

    final cellW = (width - gridHorizontalInset) / columns;
    final cellH = cellW / aspect;
    return gridPaddingVertical +
        rowCount * cellH +
        (rowCount - 1) * mainAxisSpacing;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _currentMonthIndex = now.month - 1;
    _selectedDay = _defaultDayForMonthIndex(_currentMonthIndex);

    _monthController = PageController(initialPage: _currentMonthIndex);
    _loadPersonalSchedules();
    _fetchSchedules();
  }

  Future<void> _loadPersonalSchedules() async {
    final loaded = await PreferenceManager.instance.getPersonalSchedules();
    if (mounted) {
      setState(() => _personalScheduleMap = loaded);
    }
  }

  Future<void> _persistPersonalSchedules() async {
    await PreferenceManager.instance.setPersonalSchedules(_personalScheduleMap);
  }

  Future<void> _fetchSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cached = await PreferenceManager.instance.getScheduleCache();
      if (cached != null && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _scheduleMap = cached;
            _isLoading = false;
          });
        }
        return;
      }

      final from = '${_year}0101';
      final to = '${_year}1231';
      final apiKey = dotenv.env['NEIS_API_KEY_LUNCH'] ?? '';
      final url =
          'https://open.neis.go.kr/hub/SchoolSchedule?KEY=$apiKey&Type=json&pIndex=1&pSize=365&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7531375&AA_FROM_YMD=$from&AA_TO_YMD=$to';
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
            'https://open.neis.go.kr/hub/SchoolSchedule?KEY=$apiKey&Type=json&pIndex=1&pSize=365&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=7531375&AA_FROM_YMD=$nextFrom&AA_TO_YMD=$nextTo';
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
        } catch (_) {
          // 다음 년도 데이터 가져오기 실패해도 현재 년도 데이터는 표시
        }
      }
      
      final Map<String, List<String>> filtered = {};
      map.forEach((k, v) {
        final f = v.where((e) => !e.contains('방학') && !e.contains('토요휴업일')).toList();
        if (f.isNotEmpty) filtered[k] = f;
      });
      await PreferenceManager.instance.setScheduleCache(filtered);
      if (mounted) {
        setState(() {
          _scheduleMap = filtered;
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
    final yearMonth = _getYearAndMonth(_currentMonthIndex);
    final month = yearMonth['month']!;
    final year = yearMonth['year']!;
    final List<_DayEvents> monthlyEvents = _collectMonthlyEvents(year, month);
    // MainScreen 하단 GlassNavigationBar(SizedBox 110) 위로 일정 카드만 띄움 — 겹침/전체 이동 아님
    final double listBottomPad = MediaQuery.paddingOf(context).bottom +
        ResponsiveHelper.height(context, 65) +
        ResponsiveHelper.height(context, 8);

    return Container(
      color: bgColor,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            totalMonths: _totalMonths,
            currentYear: _year,
            onIndexChanged: (i, deltaYear) {
              setState(() {
                if (i >= 12) {
                  _currentMonthIndex = i;
                } else {
                  if (deltaYear != 0) {
                    _year += deltaYear;
                  }
                  _currentMonthIndex = i;
                }
                _selectedDay = _defaultDayForMonthIndex(_currentMonthIndex);
              });

              if (deltaYear != 0) {
                _fetchSchedules();
              }
            },
          ),
          ResponsiveHelper.verticalSpace(context, 2),
          _WeekdaysRow(textColor: textColor),
          ResponsiveHelper.verticalSpace(context, 0),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _calendarPageHeight(context),
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child:
                              _isLoading
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
                                      setState(() {
                                        _currentMonthIndex = i;
                                        _selectedDay = _defaultDayForMonthIndex(i);
                                      });
                                    },
                                    itemCount: _totalMonths,
                                    itemBuilder: (context, index) {
                                      final yearMonth = _getYearAndMonth(index);
                                      final m = yearMonth['month']!;
                                      final y = yearMonth['year']!;
                                      return SingleChildScrollView(
                                        key: PageStorageKey<String>('schedule_cal_${y}_$m'),
                                        physics: const BouncingScrollPhysics(
                                          parent: AlwaysScrollableScrollPhysics(),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom:
                                                _calendarFloatOverlap +
                                                _calendarScrollBottomPad,
                                          ),
                                          child: _MonthGrid(
                                            year: y,
                                            month: m,
                                            scheduleMap: _scheduleMap,
                                            personalScheduleMap: _personalScheduleMap,
                                            selectedDay: _selectedDay,
                                            onDaySelected: (d) {
                                              setState(() => _selectedDay = d);
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                _scrollToDay(d);
                                              });
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 32,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    bgColor.withValues(alpha: 0.55),
                                    bgColor.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 40,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    bgColor.withValues(alpha: 0.65),
                                    bgColor.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: _calendarPageHeight(context) - _calendarFloatOverlap,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: ResponsiveHelper.padding(
                          context,
                          left: 20,
                          right: 20,
                          top: 2,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ScheduleChipButton(
                                label: '일정 추가',
                                isDark: isDark,
                                enabled: _selectedDay != null,
                                onTap:
                                    _selectedDay == null
                                        ? null
                                        : () => _openAddPersonalSchedule(context, isDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ScheduleChipButton(
                                label: '일정 삭제',
                                isDark: isDark,
                                enabled:
                                    _selectedDay != null &&
                                    (_personalScheduleMap[_scheduleYmdKey(
                                              year,
                                              month,
                                              _selectedDay!,
                                            )]?.isNotEmpty ??
                                        false),
                                onTap:
                                    _selectedDay == null
                                        ? null
                                        : () => _openDeletePersonalSchedule(context, isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: ResponsiveHelper.padding(
                            context,
                            left: 20,
                            right: 20,
                            top: 0,
                          ).copyWith(bottom: listBottomPad),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_DayEvents> _collectMonthlyEvents(int year, int month) {
    final Map<int, List<String>> dayToEvents = {};
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _scheduleYmdKey(year, month, d);
      final school = _scheduleMap[key] ?? const <String>[];
      final personal = _personalScheduleMap[key] ?? const <String>[];
      if (school.isEmpty && personal.isEmpty) continue;
      dayToEvents[d] = [...school, ...personal];
    }
    final days = dayToEvents.keys.toList()..sort();
    return days.map((d) => _DayEvents(day: d, events: dayToEvents[d]!.toList())).toList();
  }

  void _openAddPersonalSchedule(BuildContext context, bool isDark) {
    final ym = _getYearAndMonth(_currentMonthIndex);
    final y = ym['year']!;
    final m = ym['month']!;
    final d = _selectedDay!;
    final dateKey = _scheduleYmdKey(y, m, d);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (ctx) => _AddPersonalScheduleDialog(
            isDark: isDark,
            initialItems: List<String>.from(_personalScheduleMap[dateKey] ?? []),
            onCommit: (list) {
              setState(() {
                if (list.isEmpty) {
                  _personalScheduleMap.remove(dateKey);
                } else {
                  _personalScheduleMap[dateKey] = list;
                }
              });
              _persistPersonalSchedules();
            },
          ),
    );
  }

  void _openDeletePersonalSchedule(BuildContext context, bool isDark) {
    final ym = _getYearAndMonth(_currentMonthIndex);
    final y = ym['year']!;
    final m = ym['month']!;
    final d = _selectedDay!;
    final dateKey = _scheduleYmdKey(y, m, d);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (ctx) => _DeletePersonalScheduleDialog(
            isDark: isDark,
            initialItems: List<String>.from(_personalScheduleMap[dateKey] ?? []),
            onCommit: (list) {
              setState(() {
                if (list.isEmpty) {
                  _personalScheduleMap.remove(dateKey);
                } else {
                  _personalScheduleMap[dateKey] = list;
                }
              });
              _persistPersonalSchedules();
            },
          ),
    );
  }

  void _scrollToDay(int day) {
    if (!_listController.hasClients) return;
    
    final yearMonth = _getYearAndMonth(_currentMonthIndex);
    final year = yearMonth['year']!;
    final month = yearMonth['month']!;
    final monthlyEvents = _collectMonthlyEvents(year, month);
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
            // 7개 슬롯이 보이므로 최대 스크롤 인덱스 = totalMonths - 7
            final maxScrollIndex = (totalMonths - 7).clamp(0, totalMonths);
            int scrollOffset = (currentIndex - 3).clamp(0, maxScrollIndex);
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
                  
                  // 7개 슬롯이 보이므로 첫 번째 보이는 월 인덱스 = min(currentIndex-3, totalMonths-7)
                  final maxScrollIndex = (totalMonths - 7).clamp(0, totalMonths);
                  final scrollBase = (currentIndex - 3).clamp(0, maxScrollIndex);
                  double localIndex = (page - scrollBase).clamp(0.0, 6.0);
                  
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
  final Map<String, List<String>> personalScheduleMap;
  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.scheduleMap,
    required this.personalScheduleMap,
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
      final dateStr = _scheduleYmdKey(year, month, d);
      final schoolEvents = scheduleMap[dateStr] ?? const <String>[];
      final personalEvents = personalScheduleMap[dateStr] ?? const <String>[];
      final hasEvent = schoolEvents.isNotEmpty || personalEvents.isNotEmpty;
      final capsuleLabel =
          personalEvents.isNotEmpty
              ? personalEvents.first
              : (schoolEvents.isNotEmpty ? schoolEvents.first : null);
      final isToday = today.year == year && today.month == month && today.day == d;
      final isSelected = selectedDay == d;

      // 연속 일정 정보 확인
      final continuousInfo = continuousEvents[d];

      const double dayCircleSize = 32;
      cells.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onDaySelected(d),
          child: SizedBox.expand(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 3),
                Container(
                  width: dayCircleSize,
                  height: dayCircleSize,
                  decoration: isToday
                      ? const BoxDecoration(
                          color: Color(0xFFFFC51D),
                          shape: BoxShape.circle,
                        )
                      : isSelected
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFC51D),
                            width: 2,
                          ),
                        )
                      : null,
                  child: Center(
                    child: Text(
                      '$d',
                      style: TextStyle(
                        color: isToday
                            ? Colors.black
                            : (isDark ? Colors.white : Colors.black),
                        fontWeight: hasEvent
                            ? FontWeight.w600
                            : (isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                if (continuousInfo == null && capsuleLabel != null)
                  _DayCapsule(
                    text: capsuleLabel,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final eventRanges = _analyzeEventRanges();

    // GridView가 먼저 높이를 정한 뒤 Positioned.fill로 막대 레이어에 유한 제약을 준다.
    // (ScrollView 안에서 LayoutBuilder를 GridView와 형제로 두면 세로 무한 제약으로 레이아웃 실패)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final range in eventRanges)
                        ..._rangeBarWidgets(range, isDark, startWeekday, w),
                    ],
                  );
                },
              ),
            ),
          ),
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
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final Set<int> personalDays = {};
    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = _scheduleYmdKey(year, month, d);
      if ((personalScheduleMap[dateStr] ?? []).isNotEmpty) {
        personalDays.add(d);
      }
    }

    final Map<String, List<int>> eventToDays = {};
    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = _scheduleYmdKey(year, month, d);
      final events = scheduleMap[dateStr] ?? const <String>[];
      if (events.isNotEmpty) {
        eventToDays.putIfAbsent(events.first, () => []).add(d);
      }
    }

    eventToDays.forEach((eventName, days) {
      if (days.length < 2) return;
      days.sort();

      final List<List<int>> mergedRanges = [];
      List<int> currentRange = [days.first];

      for (int i = 1; i < days.length; i++) {
        if (days[i] == days[i - 1] + 1) {
          currentRange.add(days[i]);
        } else {
          mergedRanges.addAll(
            _subRangesExcludingPersonal(currentRange, personalDays),
          );
          currentRange = [days[i]];
        }
      }
      mergedRanges.addAll(
        _subRangesExcludingPersonal(currentRange, personalDays),
      );

      for (final range in mergedRanges) {
        if (range.length < 2) continue;
        for (int i = 0; i < range.length; i++) {
          final day = range[i];
          final _CapsulePosition position;
          if (i == 0) {
            position =
                range.length == 1
                    ? _CapsulePosition.single
                    : _CapsulePosition.start;
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
    final Set<int> personalDays = {};

    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = _scheduleYmdKey(year, month, d);
      if ((personalScheduleMap[dateStr] ?? []).isNotEmpty) {
        personalDays.add(d);
      }
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = _scheduleYmdKey(year, month, d);
      final events = scheduleMap[dateStr] ?? const <String>[];
      if (events.isNotEmpty) {
        eventToDays.putIfAbsent(events.first, () => []).add(d);
      }
    }

    final List<_EventRange> ranges = [];
    eventToDays.forEach((eventName, days) {
      if (days.length < 2) return;
      days.sort();

      List<int> current = [days.first];
      for (int i = 1; i < days.length; i++) {
        if (days[i] == days[i - 1] + 1) {
          current.add(days[i]);
        } else {
          for (final sub in _subRangesExcludingPersonal(current, personalDays)) {
            if (sub.length >= 2) {
              ranges.add(
                _EventRange(eventName: eventName, days: List.from(sub)),
              );
            }
          }
          current = [days[i]];
        }
      }
      for (final sub in _subRangesExcludingPersonal(current, personalDays)) {
        if (sub.length >= 2) {
          ranges.add(_EventRange(eventName: eventName, days: sub));
        }
      }
    });

    return ranges;
  }

  List<Widget> _rangeBarWidgets(
    _EventRange range,
    bool isDark,
    int startWeekday,
    double gridWidth,
  ) {
    const int columns = 7;
    const double crossAxisSpacing = 0;
    const double mainAxisSpacing = 1;
    const double aspect = 0.95;
    const double gridTopPadding = 4;
    final double cellWidth = (gridWidth - (columns - 1) * crossAxisSpacing) / columns;
    final double cellHeight = cellWidth / aspect;

    const double dateTopOffset = 3 + 32 + 1;

    final firstDay = range.days.first;
    final lastDay = range.days.last;
    final firstGridIndex = startWeekday + firstDay - 1;
    final lastGridIndex = startWeekday + lastDay - 1;
    final firstRow = firstGridIndex ~/ columns;
    final firstCol = firstGridIndex % columns;
    final lastRow = lastGridIndex ~/ columns;
    final lastCol = lastGridIndex % columns;

    final List<Widget> bars = [];
    for (int row = firstRow; row <= lastRow; row++) {
      final int startCol = (row == firstRow) ? firstCol : 0;
      final int endCol = (row == lastRow) ? lastCol : columns - 1;
      final double left = startCol * (cellWidth + crossAxisSpacing);
      final double top = gridTopPadding + row * (cellHeight + mainAxisSpacing) + dateTopOffset;
      final double width =
          (endCol - startCol + 1) * cellWidth + (endCol - startCol) * crossAxisSpacing;

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
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 8,
                    height: 1.0,
                  ),
                )
              : null,
        ),
      ));
    }

    return bars;
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

class _ScheduleChipButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool enabled;
  final VoidCallback? onTap;

  const _ScheduleChipButton({
    required this.label,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final fg = isDark ? AppColors.darkText : AppColors.lightText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: AppShadows.card(isDark),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: enabled ? 1.0 : 0.38),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPersonalScheduleDialog extends StatefulWidget {
  final bool isDark;
  final List<String> initialItems;
  final void Function(List<String> items) onCommit;

  const _AddPersonalScheduleDialog({
    required this.isDark,
    required this.initialItems,
    required this.onCommit,
  });

  @override
  State<_AddPersonalScheduleDialog> createState() =>
      _AddPersonalScheduleDialogState();
}

class _AddPersonalScheduleDialogState extends State<_AddPersonalScheduleDialog> {
  late List<String> _items;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.initialItems);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items = [..._items, text];
      _controller.clear();
    });
    widget.onCommit(List<String>.from(_items));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = widget.isDark ? AppColors.darkText : AppColors.lightText;
    final fieldFill =
        widget.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04);

    return Dialog(
      backgroundColor: card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '일정 추가',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.75)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '일정을 입력해주세요',
                      hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: textColor.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: textColor.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: textColor.withValues(alpha: 0.35),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: card,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _add,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: textColor.withValues(alpha: 0.16),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '추가',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _PersonalScheduleItemBox(
                        text: _items[i],
                        textColor: textColor,
                        fillColor: fieldFill,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeletePersonalScheduleDialog extends StatefulWidget {
  final bool isDark;
  final List<String> initialItems;
  final void Function(List<String> items) onCommit;

  const _DeletePersonalScheduleDialog({
    required this.isDark,
    required this.initialItems,
    required this.onCommit,
  });

  @override
  State<_DeletePersonalScheduleDialog> createState() =>
      _DeletePersonalScheduleDialogState();
}

class _DeletePersonalScheduleDialogState
    extends State<_DeletePersonalScheduleDialog> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.initialItems);
  }

  void _removeAt(int index) {
    setState(() {
      _items.removeAt(index);
    });
    widget.onCommit(List<String>.from(_items));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = widget.isDark ? AppColors.darkText : AppColors.lightText;
    final fieldFill =
        widget.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04);

    return Dialog(
      backgroundColor: card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '일정 삭제',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.75)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Text(
                '삭제할 일정이 없습니다.',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _PersonalScheduleItemBox(
                              text: _items[i],
                              textColor: textColor,
                              fillColor: fieldFill,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _removeAt(i),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonalScheduleItemBox extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color fillColor;

  const _PersonalScheduleItemBox({
    required this.text,
    required this.textColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: textColor.withValues(alpha: 0.12),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        '· $text',
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}
