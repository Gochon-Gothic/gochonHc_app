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
}

