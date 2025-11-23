import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'screens/timetable_screen.dart';
import 'screens/bus_search_screen.dart';
import 'screens/lunch_screen.dart';
import 'screens/my_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/notice_detail_screen.dart';
import 'screens/notice_list_screen.dart';
import 'widgets/glass_navigation_bar.dart';
import 'models/user_info.dart';
import 'models/notice.dart';
import 'theme_provider.dart';
import 'theme_colors.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'services/gsheet_service.dart';
import 'dart:convert';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController(initialPage: 2);
  int _selectedIndex = 2;
  Key _homeKey = UniqueKey();
  UserInfo? userInfo;
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> schedules = [];

  static const String _apiKey = 'c47f72f8b5a740f9956194fcd2112c27';
  static const String _eduOfficeCode = 'J10';
  static const String _schoolCode = '7531375';

  List<Widget> get _pages => [
    const BusSearchScreen(),
    const TimetableScreen(),
    _MainHomeContent(
      key: _homeKey,
      userInfo: userInfo,
      schedules: schedules,
      isLoading: isLoading,
      error: error,
      onRefresh: fetchSchedule,
    ),
    const LunchScreen(),
    const MyScreen(),
  ];

  void _onPageChanged(int index) {
    setState(() {
      if (_selectedIndex == 2 && index != 2) {
        _homeKey = UniqueKey();
      }
      _selectedIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    fetchSchedule();
  }

  Future<void> _loadUserInfo() async {
    try {
      var loadedUserInfo = await UserService.instance.getUserInfo();
      if (loadedUserInfo == null) {
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          final userData = await AuthService.instance.getUserFromFirestore(currentUser.uid);
          if (userData != null) {
            loadedUserInfo = UserInfo.fromJson(userData);
            await UserService.instance.saveUserInfo(loadedUserInfo);
          }
        }
      }
      if (mounted) {
        setState(() {
          userInfo = loadedUserInfo;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '사용자 정보를 불러오는데 실패했습니다: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchSchedule() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final today = DateTime.now();
      final endDate = today.add(const Duration(days: 30));
      final url = 'https://open.neis.go.kr/hub/SchoolSchedule'
          '?KEY=$_apiKey'
          '&Type=json'
          '&pIndex=1'
          '&pSize=30'
          '&ATPT_OFCDC_SC_CODE=$_eduOfficeCode'
          '&SD_SCHUL_CODE=$_schoolCode'
          '&AA_FROM_YMD=${DateFormat('yyyyMMdd').format(today)}'
          '&AA_TO_YMD=${DateFormat('yyyyMMdd').format(endDate)}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['RESULT'] != null && data['RESULT']['CODE'] == 'INFO-200') {
        setState(() {
          schedules = [];
          isLoading = false;
        });
        return;
      }

      if (data['SchoolSchedule'] == null) {
        throw Exception('학사일정 데이터가 없습니다.');
      }

      final rows = data['SchoolSchedule'][1]['row'] as List;
      final filteredRows = rows
          .map((row) => row as Map<String, dynamic>)
          .where((row) {
            final name = (row['EVENT_NM'] as String).replaceAll(' ', '');
            return !name.contains('토요휴업일');
          })
          .toList()
        ..sort((a, b) => (a['AA_YMD'] as String).compareTo(b['AA_YMD'] as String));

      setState(() {
        schedules = filteredRows.take(3).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = '학사일정을 불러오는데 실패했습니다: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Container(
                color: bgColor,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const ClampingScrollPhysics(),
                  children: _pages,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GlassNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: _onTabTapped,
                  pageController: _pageController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MainHomeContent extends StatefulWidget {
  final UserInfo? userInfo;
  final List<Map<String, dynamic>> schedules;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;

  const _MainHomeContent({
    super.key,
    required this.userInfo,
    required this.schedules,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  State<_MainHomeContent> createState() => _MainHomeContentState();
}

class _MainHomeContentState extends State<_MainHomeContent> {
  bool _showSchedule = false;
  List<Notice> _notices = [];
  bool _noticesLoading = true;
  String? _noticesError;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _noticesLoading = true;
      _noticesError = null;
    });

    try {
      final notices = await GSheetService.getNotices(limit: 2);
      if (mounted) {
        setState(() {
          _notices = notices;
          _noticesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _noticesError = e.toString();
          _noticesLoading = false;
        });
      }
    }
  }

  Widget _buildLoadingState(Color textColor) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: CircularProgressIndicator(color: textColor),
    ),
  );

  Widget _buildErrorState(String message, Color textColor) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _buildEmptyState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        message,
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    ),
  );

  Widget buildScheduleCard(bool isDark, Color textColor, Color cardColor) {
    if (widget.isLoading) return _buildLoadingState(textColor);
    if (widget.error != null) return _buildErrorState(widget.error!, textColor);
    if (widget.schedules.isEmpty) return _buildEmptyState('다가오는 학사일정이 없습니다.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.schedules.map((schedule) {
        final date = schedule['AA_YMD'] as String;
        final event = schedule['EVENT_NM'] as String;
        final formattedDate = '${date.substring(4, 6)}월 ${date.substring(6, 8)}일';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('· ', style: TextStyle(fontSize: 18, color: textColor)),
              Expanded(
                child: Text(
                  '$formattedDate $event',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildNoticeCard(bool isDark, Color textColor) {
    if (_noticesLoading) return _buildLoadingState(textColor);
    if (_noticesError != null) {
      return _buildErrorState('공지사항을 불러오는데 실패했습니다.', textColor);
    }
    if (_notices.isEmpty) return _buildEmptyState('공지사항이 없습니다.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _notices.asMap().entries.map((entry) {
        final isLast = entry.key == _notices.length - 1;
        final notice = entry.value;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoticeDetailScreen(notice: notice),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: TextStyle(fontSize: 18, color: textColor)),
                Expanded(
                  child: Text(
                    notice.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onMore, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                letterSpacing: 0,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 7),
            Container(width: 73, height: 2, color: textColor),
          ],
        ),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: Text(
              '더보기',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardContainer(Widget child, Color cardColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : const Color.fromRGBO(21, 21, 21, 0.5),
            offset: const Offset(0, 0),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: MediaQuery.of(context).size.width,
        color: bgColor,
        child: _showSchedule
            ? ScheduleView(onExit: () => setState(() => _showSchedule = false))
            : NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo is ScrollUpdateNotification) {
                    if (scrollInfo.metrics.pixels > scrollInfo.metrics.maxScrollExtent * 1.1) {
                      return true;
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  Text(
                                    '고촌고등학교',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 41,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AuthService.instance.currentUser == null
                                        ? '환영합니다, 게스트님'
                                        : (widget.userInfo?.welcomeMessage ?? '로그인 정보를 불러오는 중...'),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Transform.translate(
                                offset: const Offset(0, 5),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: SvgPicture.asset(
                                    'assets/images/gochon_logo.svg',
                                    semanticsLabel: 'Gochon Logo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 38),
                        Center(
                          child: Container(
                            width: 371,
                            height: 235,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white : AppColors.lightBorder,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : const Color.fromRGBO(0, 0, 0, 0.25),
                                  offset: const Offset(0, 4),
                                  blurRadius: 16,
                                ),
                              ],
                              image: const DecorationImage(
                                image: AssetImage('assets/images/example_image.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSectionHeader(
                                '공지사항',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NoticeListScreen(),
                                    ),
                                  );
                                },
                                textColor,
                              ),
                              const SizedBox(height: 10),
                              _buildCardContainer(
                                buildNoticeCard(isDark, textColor),
                                cardColor,
                                isDark,
                              ),
                              const SizedBox(height: 15),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                '학사일정',
                                () => setState(() => _showSchedule = true),
                                textColor,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: cardColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.5)
                                          : const Color.fromRGBO(21, 21, 21, 0.5),
                                      offset: const Offset(0, 0),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: buildScheduleCard(isDark, textColor, cardColor),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'SFPro'),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'SFPro'),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainScreen(),
    );
  }
}
