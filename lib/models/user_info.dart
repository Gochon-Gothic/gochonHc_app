class UserInfo {
  final int grade; // 학년
  final int classNum; // 반
  final int number; // 번호
  final String email; // 이메일
  final String name; // 사용자 이름

  UserInfo({
    required this.grade,
    required this.classNum,
    required this.number,
    required this.email,
    required this.name,
  });

  String get welcomeMessage {
    if (name.isNotEmpty) {
      return '$grade학년 $classNum반 $number번, $name님 환영합니다';
    } else {
      return '$grade학년 $classNum반 $number번님, 환영합니다';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'grade': grade,
      'classNum': classNum,
      'number': number,
    };
  }

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      grade: json['grade'] ?? 1,
      classNum: json['classNum'] ?? 1,
      number: json['number'] ?? 1,
    );
  }

  UserInfo copyWith({
    String? email,
    String? name,
    int? grade,
    int? classNum,
    int? number,
  }) {
    return UserInfo(
      email: email ?? this.email,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      classNum: classNum ?? this.classNum,
      number: number ?? this.number,
    );
  }
}
