/// 공지사항 데이터 모델
///
/// [로직 흐름]
/// 1. date, title, content 필드로 공지 정보 저장
/// 2. fromJson: JSON(Map) → Notice 객체 변환 (Firestore/API 응답 파싱용)
/// 3. toJson: Notice 객체 → JSON(Map) 변환 (저장/전송용)
class Notice {
  final String date;
  final String title;
  final String content;

  Notice({
    required this.date,
    required this.title,
    required this.content,
  });

  /// JSON → Notice 변환
  /// - 각 필드가 없으면 빈 문자열로 대체
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
