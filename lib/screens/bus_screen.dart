import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../services/bus_service.dart';
import 'bus_station_screen.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BusStation> searchResults = [];
  bool isSearching = false;
  
  final List<Map<String, String>> popularStations = [
    {'name': '고촌역', 'keyword': '고촌역'},
    {'name': '장곡•고촌고등학교', 'keyword': '장곡'},
    {'name': '장곡', 'keyword': '장곡'},
    {'name': '김포공항', 'keyword': '김포공항'},
    {'name': '김포시청', 'keyword': '김포시청'},
    {'name': '운양역', 'keyword': '운양역'},
    {'name': '사우역', 'keyword': '사우역'},
    {'name': '풍무역', 'keyword': '풍무역'},
    {'name': '구래역', 'keyword': '구래역'},
    {'name': '마산역', 'keyword': '마산역'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchStations(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final results = await BusService.searchStations(keyword);
      if (mounted) {
        setState(() {
          searchResults = results;
          isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          searchResults = [];
          isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _navigateToStation(BusStation station) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusStationScreen(station: station),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '버스 알림',
              style: TextStyle(
                fontSize: 40,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 검색창
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color.fromRGBO(21, 21, 21, 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: textColor.withValues(alpha: 0.6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: '정류장명 또는 번호를 입력하세요',
                      hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: _searchStations,
                  ),
                ),
                if (isSearching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 검색 결과 또는 인기 정류장
          if (_searchController.text.isNotEmpty && searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '검색 결과 (${searchResults.length}개)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...searchResults.take(10).map((station) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.directions_bus,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                      title: Text(
                        station.stationName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '정류장 번호: ${station.stationNum}',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: textColor.withValues(alpha: 0.4),
                        size: 16,
                      ),
                      onTap: () => _navigateToStation(station),
                    ),
                  ),
                )),
          ] else if (_searchController.text.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '인기 정류장',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...popularStations.map((station) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(255, 197, 30, 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.star,
                          color: const Color.fromRGBO(255, 197, 30, 1),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        station['name']!,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: textColor.withValues(alpha: 0.4),
                        size: 16,
                      ),
                      onTap: () => _searchStations(station['keyword']!),
                    ),
                  ),
                )),
          ] else if (_searchController.text.isNotEmpty && searchResults.isEmpty && !isSearching) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '정류장명이나 번호를 정확히 입력해주세요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
