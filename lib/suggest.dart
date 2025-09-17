import 'package:flutter/material.dart';


import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'theme_colors.dart';
import 'services/gsheet_service.dart';
import 'utils/shadows.dart';

class SuggestScreen extends StatefulWidget {
  const SuggestScreen({super.key});

  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends State<SuggestScreen> {
  bool isLoading = true;
  String? error;
  List<Map<String, String>> suggestions = [];
  String? currentUserEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadSuggestions();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserEmail = prefs.getString('user_email');
    });
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loadedSuggestions = await GSheetService.getAllSuggestions();
      if (mounted) {
        setState(() {
          suggestions = loadedSuggestions;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '건의사항을 불러오는데 실패했습니다.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // 상단 여백
          const SizedBox(height: 60),
          // 건의함 제목과 + 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '건의함',
                  style: TextStyle(
                    fontSize: 40,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primary : Colors.black,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: IconButton(
                      onPressed: () => _showAddSuggestionDialog(context),
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 건의함 박스
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.card(isDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // 건의사항 리스트
                if (isLoading)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                else if (error != null)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else if (suggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        '아직 건의사항이 없습니다.\n첫 번째 건의를 남겨보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  ...suggestions.map(
                    (suggestion) => SuggestionCard(
                      id: suggestion['ID']!,
                      title: suggestion['제목']!,
                      date: suggestion['날짜']!,
                      author: suggestion['작성자']!,
                      content: suggestion['내용']!,
                      authorEmail: suggestion['이메일']!,
                      currentUserEmail: currentUserEmail,
                      isDark: isDark,
                      textColor: textColor,
                      cardColor: cardColor,
                      onTap: () => _showSuggestionDetail(suggestion),
                      onDelete: () => _deleteSuggestion(suggestion['ID']!),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSuggestionDetail(Map<String, String> suggestion) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SuggestionDetailScreen(
              suggestion: suggestion,
              currentUserEmail: currentUserEmail,
              onDelete: () => _deleteSuggestion(suggestion['ID']!),
            ),
      ),
    );
  }

  void _showAddSuggestionDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => AddSuggestionScreen(
              onSuggestionAdded:
                  (title, content) => _addSuggestion(title, content),
            ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _addSuggestion(String title, String content) async {
    final prefs = await SharedPreferences.getInstance();
    final authorName = prefs.getString('user_name') ?? '익명';
    final authorEmail = prefs.getString('user_email') ?? '';

    try {
      final id = await GSheetService.saveSuggestion(
        title: title,
        content: content,
        authorName: authorName,
        authorEmail: authorEmail,
      );

      if (id != null) {
        await _loadSuggestions();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('건의사항이 등록되었습니다.')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('건의사항 등록에 실패했습니다.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('건의사항 등록 중 오류가 발생했습니다.')));
      }
    }
  }

  Future<void> _deleteSuggestion(String id) async {
    try {
      final success = await GSheetService.deleteSuggestion(id);
      if (success) {
        await _loadSuggestions();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('건의사항이 삭제되었습니다.')));
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('건의사항 삭제에 실패했습니다.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('건의사항 삭제 중 오류가 발생했습니다.')));
      }
    }
  }
}

class SuggestionCard extends StatelessWidget {
  final String id;
  final String title;
  final String date;
  final String author;
  final String content;
  final String authorEmail;
  final String? currentUserEmail;
  final bool isDark;
  final Color textColor;
  final Color cardColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SuggestionCard({
    required this.id,
    required this.title,
    required this.date,
    required this.author,
    required this.content,
    required this.authorEmail,
    required this.currentUserEmail,
    required this.isDark,
    required this.textColor,
    required this.cardColor,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  String _formatDate(String dateStr) {
    try {
      // Google Sheets에서 오는 날짜가 이미 포맷된 문자열이면 그대로 사용
      if (dateStr.contains('-') && dateStr.contains(':')) {
        return dateStr.split(' ')[0]; // 날짜 부분만 반환
      }

      // 숫자로 온 경우 현재 날짜로 대체
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } catch (e) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,

              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 14,
    
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  author,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
    
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestionDetailScreen extends StatelessWidget {
  final Map<String, String> suggestion;
  final String? currentUserEmail;
  final VoidCallback onDelete;

  const SuggestionDetailScreen({
    required this.suggestion,
    required this.currentUserEmail,
    required this.onDelete,
    super.key,
  });

  String _formatDateDetail(String dateStr) {
    try {
      if (dateStr.contains('-') && dateStr.contains(':')) {
        return dateStr.split(' ')[0];
      }

      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } catch (e) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    final isAuthor =
        currentUserEmail != null && currentUserEmail == suggestion['이메일'];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (isAuthor)
            IconButton(
              onPressed: () => _showDeleteDialog(context),
              icon: Icon(Icons.delete_outline, color: textColor),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.card(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                suggestion['제목']!,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
  
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _formatDateDetail(suggestion['날짜'] ?? ''),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 16,
      
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    suggestion['작성자'] ?? '익명',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
      
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 구분선
              Container(
                height: 1,
                width: double.infinity,
                color:
                    isDark
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              // 본문 내용
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  suggestion['내용'] ?? '',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    height: 1.6,
    
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            '건의사항 삭제',
            style: TextStyle(
              color: textColor,

            ),
          ),
          content: Text(
            '이 건의사항을 삭제하시겠습니까?',
            style: TextStyle(
              color: textColor,

            ),
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('취소', style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete();
              },
              child: Text('삭제', style: TextStyle(color: textColor)),
            ),
          ],
        );
      },
    );
  }
}

class AddSuggestionScreen extends StatefulWidget {
  final Function(String title, String content) onSuggestionAdded;

  const AddSuggestionScreen({required this.onSuggestionAdded, super.key});

  @override
  State<AddSuggestionScreen> createState() => _AddSuggestionScreenState();
}

class _AddSuggestionScreenState extends State<AddSuggestionScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소', style: TextStyle(color: textColor, fontSize: 16)),
        ),
        actions: [
          TextButton(
            onPressed:
                (_canSubmit() && !isSubmitting) ? _submitSuggestion : null,
            child: Text(
              '올리기',
              style: TextStyle(
                color:
                    (_canSubmit() && !isSubmitting)
                        ? (isDark ? AppColors.primary : const Color.fromARGB(255, 203, 204, 208))
                        : textColor.withValues(alpha: 0.4),
                fontSize: 16,
                fontWeight: FontWeight.w600,

              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '제목',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
      
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      color: textColor,
      
                    ),
                    decoration: InputDecoration(
                      hintText: '건의사항 제목을 입력하세요',
                      hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
        
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.primary : const Color.fromARGB(255, 203, 204, 208),
                        ),
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '내용',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
      
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    style: TextStyle(
                      color: textColor,
      
                    ),
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: '건의사항 내용을 자세히 입력하세요',
                      hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
        
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.primary : const Color.fromARGB(255, 203, 204, 208),
                        ),
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ],
              ),
            ),
            if (isSubmitting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    return _titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty;
  }

  Future<void> _submitSuggestion() async {
    if (_canSubmit() && !isSubmitting) {
      setState(() {
        isSubmitting = true;
      });

      await widget.onSuggestionAdded(
        _titleController.text.trim(),
        _contentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
