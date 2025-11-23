class Notice {
  final String date;
  final String title;
  final String content;

  Notice({
    required this.date,
    required this.title,
    required this.content,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'title': title,
      'content': content,
    };
  }

  DateTime? get parsedDate {
    if (date.isEmpty) return null;
    try {
      final cleaned = date.trim();
      
      if (RegExp(r'^\d+$').hasMatch(cleaned)) {
        final serialNumber = int.parse(cleaned);
        if (serialNumber > 40000 && serialNumber < 50000) {
          final epoch = DateTime(1899, 12, 30);
          return epoch.add(Duration(days: serialNumber));
        }
        return null;
      }
      
      final parts = cleaned.split('/');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        if (year > 2000 && year < 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {
    }
    return null;
  }

  String get formattedDate {
    return date;
  }
}

