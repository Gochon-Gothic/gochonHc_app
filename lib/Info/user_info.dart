class UserInfo {
  final int grade; // 학년
  final int classNum; // 반
  final int number; // 번호
  final String email; // 이메일
  final String? name; // 사용자 이름 (선택적)

  UserInfo({
    required this.grade,
    required this.classNum,
    required this.number,
    required this.email,
    this.name,
  });

  // 이메일에서 사용자 정보 파싱
  static UserInfo? fromEmail(String email) {
    try {
      // 이메일 형식: 25-20504@gochon.hs.kr
      final parts = email.split('@')[0].split('-');
      if (parts.length != 2) return null;

      final studentId = parts[1];
      if (studentId.length != 5) return null;

      final grade = int.parse(studentId[0]);
      final classNum = int.parse(studentId.substring(1, 3));
      final number = int.parse(studentId.substring(3, 5));

      return UserInfo(
        grade: grade,
        classNum: classNum,
        number: number,
        email: email,
      );
    } catch (e) {
      return null;
    }
  }

  // 환영 메시지용 문자열
  String get welcomeMessage {
    if (name != null && name!.isNotEmpty) {
      return '$grade학년 $classNum반 $number번, $name님 환영합니다';
    } else {
      return '$grade학년 $classNum반 $number번님, 환영합니다';
    }
  }
}
