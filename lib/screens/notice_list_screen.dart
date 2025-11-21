import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../theme_colors.dart';
import '../theme_provider.dart';
import '../services/gsheet_service.dart';
import 'notice_detail_screen.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  List<Notice> _allNotices = [];
  List<Notice> _filteredNotices = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int _currentPage = 1;
  Timer? _debounceTimer;
  
  static const int _itemsPerPage = 15;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notices = await GSheetService.getNotices(limit: 1000);
      if (mounted) {
        setState(() {
          _allNotices = notices;
          _filteredNotices = notices;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _filteredNotices = _allNotices;
        } else {
          final lowerQuery = query.toLowerCase();
          _filteredNotices = _allNotices
              .where((notice) =>
                  notice.title.toLowerCase().contains(lowerQuery) ||
                  notice.content.toLowerCase().contains(lowerQuery))
              .toList();
        }
        _currentPage = 1;
      });
    });
  }

  int get _totalPages => _filteredNotices.isEmpty
      ? 1
      : (_filteredNotices.length / _itemsPerPage).ceil();

  List<Notice> get _currentPageNotices {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredNotices.sublist(
      startIndex,
      endIndex > _filteredNotices.length ? _filteredNotices.length : endIndex,
    );
  }

  void _navigateToDetail(Notice notice) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoticeDetailScreen(notice: notice)),
    );
  }

  void _changePage(int pageNumber) {
    setState(() => _currentPage = pageNumber);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  Widget _buildSearchBar(bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color.fromRGBO(0, 0, 0, 0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: '공지사항 검색',
            hintStyle: TextStyle(color: secondaryTextColor),
            prefixIcon: Icon(Icons.search, color: secondaryTextColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchFocusNode.unfocus(),
        ),
      ),
    );
  }

  Widget _buildNoticeItem(Notice notice, bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return GestureDetector(
      onTap: () => _navigateToDetail(notice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color.fromRGBO(0, 0, 0, 0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice.title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              notice.formattedDate,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(bool isDark, Color bgColor, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: secondaryTextColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          final pageNumber = index + 1;
          final isActive = pageNumber == _currentPage;
          return GestureDetector(
            onTap: () => _changePage(pageNumber),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? textColor
                      : secondaryTextColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$pageNumber',
                  style: TextStyle(
                    color: isActive ? textColor : secondaryTextColor,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '공지사항',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark, cardColor, textColor, secondaryTextColor),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            '공지사항을 불러오는데 실패했습니다.',
                            style: TextStyle(color: textColor, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _filteredNotices.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                _searchQuery.isEmpty
                                    ? '공지사항이 없습니다.'
                                    : '검색 결과가 없습니다.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _currentPageNotices.length,
                            itemBuilder: (context, index) {
                              return _buildNoticeItem(
                                _currentPageNotices[index],
                                isDark,
                                cardColor,
                                textColor,
                                secondaryTextColor,
                              );
                            },
                          ),
          ),
          if (!_isLoading && _error == null && _filteredNotices.isNotEmpty)
            _buildPagination(isDark, bgColor, textColor, secondaryTextColor),
        ],
      ),
    );
  }
}
