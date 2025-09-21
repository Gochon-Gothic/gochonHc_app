import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';

class BusRouteDetailScreen extends StatefulWidget {
  final BusRoute route;
  final BusStation currentStation;

  const BusRouteDetailScreen({
    super.key,
    required this.route,
    required this.currentStation,
  });

  @override
  State<BusRouteDetailScreen> createState() => _BusRouteDetailScreenState();
}

class _BusRouteDetailScreenState extends State<BusRouteDetailScreen> {
  List<BusRouteStation> stations = [];
  BusRouteInfo? routeInfo;
  bool isLoading = true;
  String? error;
  final ScrollController _scrollController = ScrollController();
  int? currentStationIndex;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRouteData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final stationsData = await BusService.getRouteStations(widget.route.routeId);
      final routeInfoData = await BusService.getRouteInfo(widget.route.routeId);

      if (mounted) {
        setState(() {
          stations = stationsData;
          routeInfo = routeInfoData;
          isLoading = false;
          
          // 현재 역의 인덱스 찾기 (여러 방법으로 시도)
          currentStationIndex = stations.indexWhere(
            (station) => station.stationId == widget.currentStation.stationId,
          );
          
          // stationId로 매칭되지 않으면 mobileNo로 시도
          if (currentStationIndex == -1) {
            currentStationIndex = stations.indexWhere(
              (station) => station.mobileNo.trim() == widget.currentStation.stationNum.trim(),
            );
          }
          
          // mobileNo로도 매칭되지 않으면 stationName으로 시도
          if (currentStationIndex == -1) {
            currentStationIndex = stations.indexWhere(
              (station) => station.stationName == widget.currentStation.stationName,
            );
          }
          
          print('현재 역 매칭 결과:');
          print('- 현재 역 ID: ${widget.currentStation.stationId}');
          print('- 현재 역 이름: ${widget.currentStation.stationName}');
          print('- 현재 역 번호: ${widget.currentStation.stationNum}');
          print('- 매칭된 인덱스: $currentStationIndex');
          if (currentStationIndex != null && currentStationIndex! >= 0) {
            print('- 매칭된 정류장: ${stations[currentStationIndex!].stationName}');
          }
          
          // 현재 역이 화면 중앙에 오도록 스크롤
          if (currentStationIndex != null && currentStationIndex! >= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToCurrentStation();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '버스 노선 정보를 불러오는데 실패했습니다.';
          isLoading = false;
        });
      }
    }
  }

  void _scrollToCurrentStation() {
    if (currentStationIndex != null && _scrollController.hasClients) {
      final double itemHeight = 80.0; // 각 정류장 아이템의 예상 높이
      final double screenHeight = MediaQuery.of(context).size.height;
      final double targetOffset = (currentStationIndex! * itemHeight) - (screenHeight / 2) + (itemHeight / 2);
      
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _loadRouteData();
        },
        backgroundColor: Colors.grey[800],
        child: const Icon(
          Icons.refresh,
          color: Colors.white,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRouteData,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 상단 헤더
                    _buildHeader(),
                    // 검색 바
                    _buildSearchBar(),
                    // 정류장 목록
                    Expanded(
                      child: _buildStationList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[600],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 네비게이션 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.home, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 버스 노선 정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    routeInfo?.routeTypeName ?? '서울 간선버스',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    widget.route.routeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_getDestName()} 방면',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getFirstTime()}~${_getLastTime()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Q ${widget.route.routeName} 정류장 검색',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: TextButton(
            onPressed: () {
              // 내주변 정류장 기능
            },
            child: const Text('내주변 정류장'),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStationList() {
    if (stations.isEmpty) {
      return const Center(
        child: Text(
          '정류장 정보가 없습니다',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int index = 0; index < stations.length; index++) ...[
            _buildContinuousStationItem(stations[index], index, index == currentStationIndex, index == stations.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildContinuousStationItem(BusRouteStation station, int index, bool isCurrentStation, bool isLast) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 연속적인 세로선과 정류장 아이콘
            Column(
              children: [
                // 위쪽 라인 (첫 번째 정류장이 아닌 경우)
                if (index > 0) ...[
                  Container(
                    width: 3,
                    height: 24,
                    color: Colors.green[400]!,
                  ),
                ] else ...[
                  // 첫 번째 정류장의 경우 동일한 크기의 투명한 박스
                  Container(
                    width: 3,
                    height: 24,
                    color: Colors.transparent,
                  ),
                ],
                // 정류장 아이콘
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCurrentStation ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrentStation ? Colors.blue : Colors.grey[400]!,
                      width: 2,
                    ),
                    boxShadow: isCurrentStation ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
                if (!isLast) ...[
                  Container(
                    width: 3,
                    height: 24,
                    color: Colors.green[400]!,
                  ),
                ],
              ],
            ),
            const SizedBox(width: 16),
            // 정류장 정보
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      station.stationName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCurrentStation ? Colors.blue : (isDark ? AppColors.darkText : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.stationId,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkSecondaryText : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          Container(
            width: 370,
            height: 0.5,
            color: Colors.grey[300]!,
          ),
        ],
      ],
    );
  }

  String _getFirstTime() {
    if (routeInfo?.upFirstTime != null && routeInfo!.upFirstTime.isNotEmpty) {
      return routeInfo!.upFirstTime;
    }
    return '04:30';
  }

  String _getLastTime() {
    if (routeInfo?.upLastTime != null && routeInfo!.upLastTime.isNotEmpty) {
      return routeInfo!.upLastTime;
    }
    return '22:40';
  }

  String _getDestName() {
    if (routeInfo?.routeDestName != null && routeInfo!.routeDestName.isNotEmpty) {
      return routeInfo!.routeDestName;
    }
    if (widget.route.routeDestName.isNotEmpty) {
      return widget.route.routeDestName;
    }
    return '도착지';
  }

}
