/// 사용자 정보 모델 (학년, 반, 번호, 이메일, 이름)
///
/// [로직 흐름]
/// 1. grade, classNum, number: 학급 식별용
/// 2. welcomeMessage: 홈 화면 환영 문구 생성 (이름 유무에 따라 형식 분기)
/// 3. fromJson/toJson: Firestore·로컬 저장소와 데이터 교환
/// 4. copyWith: 일부 필드만 변경한 새 인스턴스 생성 (폼 수정 등에 사용)
class UserInfo {
  final int grade;
  final int classNum;
  final int number;
  final String email;
  final String name;

  UserInfo({
    required this.grade,
    required this.classNum,
    required this.number,
    required this.email,
    required this.name,
  });

  /// 환영 문구 생성
  /// - 이름 있음: "N학년 N반 N번, OOO님 환영합니다"
  /// - 이름 없음: "N학년 N반 N번님, 환영합니다"
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

  /// 전달된 필드만 교체한 새 UserInfo 반환 (나머지는 기존 값 유지)
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
