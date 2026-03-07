class AppConfig {
  // NEIS API 관련 (급식, 시간표, 학사일정)
  static const String neisApiKey = '2cf24c119b434f93b2f916280097454a';
  static const String neisApiKeyLunch = '44e1ba05c56746c5a09a5fbd5eead0be'; // 기존 코드에서 혼용됨
  static const String eduOfficeCode = 'J10';
  static const String schoolCode = '7531375';

  // 버스 API 관련 (공공데이터포털)
  static const String busServiceKey = '5603d0071b09c37c4dc6aeb25a4d08e409b4ddc2f2791e15bc113cddf228e540';
  
  // Google Apps Script (GSheet)
  static const String gsheetServiceUrl = 'https://script.google.com/macros/s/AKfycbwGsvKSB6Iw1MjSxBlIl8zPcpw7uYQZTc9IopeJVVBoN90f0Wt6AdbTCFEn2Qc6MYjT/exec';
}
