# Google Apps Script 수정 가이드 (과목/줄임말·캐시·선택수)

앱에서 **D열 3행 날짜**로 캐시 갱신 여부를 판단하고, **선택과목 세트별 선택 개수(requiredCount)** 를 쓰려면 Apps Script가 아래 형식으로 응답해야 합니다.

---

## 1. 공통: D열 3행 날짜(sheetDate) 넣기

**각 학년 시트**에서 **D3** 셀에 "데이터 기준일"을 넣습니다.  
예: `2026/3/2` (연/월/일, 슬래시 구분)

- 이 값이 **응답 JSON의 최상위**에 `sheetDate` 로 들어가야 합니다.
- 앱은 이 문자열을 그대로 캐시 키로 써서 "이미 이 날짜로 적용했는지" 비교합니다.

---

## 2. 1학년 (getGrade1Subjects)

### 시트 구조 예시

| A | B | C | D |
|---|---|---|---|
| 1 | (헤더 등) | | |
| 2 | ... | | |
| 3 | ... | ... | **2026/3/2** ← D3 = sheetDate |
| 4 | 과목명1 | 줄임말1 | |
| 5 | 과목명2 | 줄임말2 | |
| ... | | | |

- **D3**: 데이터 기준일 (예: `2026/3/2`) → 응답에 `sheetDate` 로 포함.
- **B열·C열**: 3행부터(또는 4행부터) 과목명·줄임말. 앱은 `{ "과목명": "줄임말" }` 형태를 기대합니다.

### Apps Script 응답 형식

```javascript
// 1학년
{
  "sheetDate": "2026/3/2",   // D3 셀 값 (문자열 그대로)
  "국어": "국어",
  "수학": "수학",
  "영어": "영어"
  // ... B열=키, C열=값
}
```

### 스크립트 예시 (1학년)

```javascript
function getGrade1Subjects() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('1학년'); // 시트 이름은 실제에 맞게

  var result = {};
  var sheetDate = sheet.getRange('D3').getValue();
  if (sheetDate) result.sheetDate = formatSheetDate(sheetDate);

  var data = sheet.getDataRange().getValues();
  // 3행 인덱스 = 2 (0부터). 4행부터 읽으려면 startRow = 3
  var startRow = 3; // 4행부터
  for (var r = startRow; r < data.length; r++) {
    var subject = (data[r][1] || '').toString().trim(); // B열
    var abbr = (data[r][2] || '').toString().trim();    // C열
    if (subject && abbr) result[subject] = abbr;
  }
  return result;
}

function formatSheetDate(value) {
  if (value instanceof Date) {
    return value.getFullYear() + '/' + (value.getMonth() + 1) + '/' + value.getDate();
  }
  return value.toString().trim();
}
```

---

## 3. 2학년·3학년 (getGrade2Subjects / getGrade3Subjects)

### 시트 구조 (공통과목 + 선택과목)

- **공통과목**: B·C열, 3행(또는 4행)부터 과목명·줄임말.
- **선택과목**: 세트별로 블록이 있고,
  - **2행**: 세트 이름 등. **2열(B열 또는 해당 블록의 2번째 열)에 "선택수"** (숫자).
  - **3행**: 줄임말 행 (선택수는 2행 2열에 있다고 가정).
  - **4행부터**: 과목명·줄임말.

즉, **선택과목 데이터는 4행부터** 읽으면 됩니다.

### 응답 형식 (2·3학년 공통)

```javascript
{
  "sheetDate": "2026/3/2",
  "common": {
    "공통국어": "국어",
    "공통수학": "수학"
  },
  "elective": {
    "1": {
      "setName": "선택과목명",
      "requiredCount": 3,
      "subjects": {
        "생활과 윤리": "생윤",
        "사회·문화": "사문"
      }
    },
    "2": { ... }
  }
}
```

- `sheetDate`: D3 값.
- `common`: 공통과목 `{ 과목명: 줄임말 }`.
- `elective`: 세트 번호를 문자열 키("1", "2", …)로 하고,
  - `setName`: 세트 이름,
  - `requiredCount`: **해당 세트에서 선택해야 하는 과목 개수** (2행 2열 등에서 읽은 숫자),
  - `subjects`: **4행부터** 읽은 `{ 과목명: 줄임말 }`.

---

## 4. 선택과목 세트 읽기 (2행 선택수, 4행부터 과목)

각 학년 시트에서 선택과목 블록이 아래처럼 있다고 가정합니다.

- **1행**: 헤더(예: 세트 이름)
- **2행**: 1열=라벨, **2열=선택수(숫자)** → `requiredCount`
- **3행**: 줄임말 행 (과목 데이터 아님)
- **4행~**: 과목명(B열)·줄임말(C열) → `subjects`

스크립트에서 세트 하나를 채우는 예시:

```javascript
// elective 시트 또는 블록의 범위가 있다고 가정
// setRange: 해당 세트의 범위 (예: A1:D20)
function parseElectiveSet(setRange, setNum) {
  var values = setRange.getValues();
  var setName = (values[0][0] || '').toString().trim();           // 1행 1열
  var requiredCount = parseInt(values[1][1], 10) || 0;           // 2행 2열 (선택수)
  var subjects = {};
  for (var r = 3; r < values.length; r++) {                     // 4행부터
    var subject = (values[r][1] || '').toString().trim();        // B열
    var abbr = (values[r][2] || '').toString().trim();           // C열
    if (subject && abbr) subjects[subject] = abbr;
  }
  return {
    setName: setName || ('세트' + setNum),
    requiredCount: isNaN(requiredCount) ? undefined : requiredCount,
    subjects: subjects
  };
}
```

- 2행 2열: `values[1][1]` → `requiredCount`.
- 4행부터: `values[r][1]`, `values[r][2]` → `subjects`.

---

## 5. doGet에서 action별 반환

```javascript
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) || '';
  var result;
  switch (action) {
    case 'getGrade1Subjects':
      result = getGrade1Subjects();
      break;
    case 'getGrade2Subjects':
      result = getGrade2Subjects();
      break;
    case 'getGrade3Subjects':
      result = getGrade3Subjects();
      break;
    // ... getClassCounts, 공지 등 기존 처리
    default:
      result = { error: 'unknown action' };
  }
  return ContentService.createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}
```

---

## 6. 체크리스트

| 항목 | 확인 |
|------|------|
| 1학년 시트 D3에 날짜(예: 2026/3/2) | 응답에 `sheetDate` 포함 |
| 2학년 시트 D3에 날짜 | 응답에 `sheetDate` 포함 |
| 3학년 시트 D3에 날짜 | 응답에 `sheetDate` 포함 |
| 2·3학년 공통과목 | `common` 객체 (B·C열) |
| 2·3학년 선택과목 **2행 2열** | 각 세트 `requiredCount` (숫자) |
| 2·3학년 선택과목 **4행부터** | 각 세트 `subjects` (과목명·줄임말) |

---

## 7. 날짜 형식

- D3에 **숫자(날짜)** 로 넣어도 됩니다. 스크립트에서 `formatSheetDate`로 `"yyyy/M/d"` 문자열로 바꿔서 `sheetDate`에 넣으면 앱이 파싱합니다.
- D3에 **텍스트** `2026/3/2` 로 넣어도 되고, 그대로 `sheetDate`에 넣으면 됩니다.

이렇게 수정하면 앱의 캐시·선택수·드롭다운 로직과 맞습니다.
