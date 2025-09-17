class UserInfo {
  final String email;
  final String name;
  final String grade;
  final String className;
  final String studentNumber;
  final List<String> selectedSubjects;
  final bool hasCompletedInitialSetup;
  final bool agreedToTerms;

  const UserInfo({
    required this.email,
    required this.name,
    required this.grade,
    required this.className,
    required this.studentNumber,
    required this.selectedSubjects,
    required this.hasCompletedInitialSetup,
    required this.agreedToTerms,
  });

  // 이메일에서 학번 추출 (25-20504 형식에서 20504 부분)
  static String extractStudentNumber(String email) {
    if (email.contains('@')) {
      final parts = email.split('@');
      if (parts.isNotEmpty) {
        final emailPrefix = parts[0];
        // 25-20504 형식에서 20504 부분만 추출
        if (emailPrefix.contains('-')) {
          final emailParts = emailPrefix.split('-');
          if (emailParts.length == 2) {
            return emailParts[1]; // 20504 반환
          }
        }
        return emailPrefix;
      }
    }
    return email;
  }

  // 복사본 생성 (immutable 객체)
  UserInfo copyWith({
    String? email,
    String? name,
    String? grade,
    String? className,
    String? studentNumber,
    List<String>? selectedSubjects,
    bool? hasCompletedInitialSetup,
    bool? agreedToTerms,
  }) {
    return UserInfo(
      email: email ?? this.email,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      studentNumber: studentNumber ?? this.studentNumber,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
      hasCompletedInitialSetup:
          hasCompletedInitialSetup ?? this.hasCompletedInitialSetup,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
    );
  }

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'grade': grade,
      'className': className,
      'studentNumber': studentNumber,
      'selectedSubjects': selectedSubjects,
      'hasCompletedInitialSetup': hasCompletedInitialSetup,
      'agreedToTerms': agreedToTerms,
    };
  }

  // JSON에서 객체 생성
  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      grade: json['grade'] ?? '',
      className: json['className'] ?? '',
      studentNumber: json['studentNumber'] ?? '',
      selectedSubjects: List<String>.from(json['selectedSubjects'] ?? []),
      hasCompletedInitialSetup: json['hasCompletedInitialSetup'] ?? false,
      agreedToTerms: json['agreedToTerms'] ?? false,
    );
  }

  // 기본값으로 생성
  factory UserInfo.defaultValue(String email) {
    return UserInfo(
      email: email,
      name: '',
      grade: '',
      className: '',
      studentNumber: UserInfo.extractStudentNumber(email),
      selectedSubjects: [],
      hasCompletedInitialSetup: false,
      agreedToTerms: false,
    );
  }
}
