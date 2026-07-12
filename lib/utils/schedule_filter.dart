/// 학사일정 이벤트 표시 여부.
/// - 토요휴업일 제외
/// - '방학' 포함 일정 제외 (단, '방학식'은 유지)
bool keepSchoolScheduleEvent(String eventName) {
  final name = eventName.replaceAll(' ', '');
  if (name.contains('토요휴업일')) return false;
  if (name.contains('방학식')) return true;
  if (name.contains('방학')) return false;
  return true;
}

/// 네트워크/오프라인 오류를 사용자용 문구로 변환.
String friendlyFetchError(
  Object error, {
  String fallback = '데이터를 불러오지 못했습니다.',
}) {
  final s = error.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection refused') ||
      s.contains('connection reset') ||
      s.contains('clientexception') ||
      s.contains('failed to fetch') ||
      s.contains('networkerror')) {
    return '와이파이가 연결되지 않았습니다';
  }
  return fallback;
}
