import 'package:flutter/material.dart';

class ResponsiveHelper {
  // 기준 화면 크기 (디자인 시안 기준)
  static const double designWidth = 390.0;
  static const double designHeight = 844.0;

  // 화면 크기 가져오기
  static Size screenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }

  // 화면 너비 가져오기
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  // 화면 높이 가져오기
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // 너비 비율 계산 (디자인 기준으로 스케일링)
  static double width(BuildContext context, double designWidthValue) {
    final width = screenWidth(context);
    return (designWidthValue / designWidth) * width;
  }

  // 높이 비율 계산 (디자인 기준으로 스케일링)
  static double height(BuildContext context, double designHeightValue) {
    final height = screenHeight(context);
    return (designHeightValue / designHeight) * height;
  }

  // 폰트 크기 스케일링
  static double fontSize(BuildContext context, double designFontSize) {
    final width = screenWidth(context);
    final scale = width / designWidth;
    return designFontSize * scale;
  }

  // 수평 패딩 스케일링
  static EdgeInsets horizontalPadding(BuildContext context, double designPadding) {
    return EdgeInsets.symmetric(horizontal: width(context, designPadding));
  }

  // 수직 패딩 스케일링
  static EdgeInsets verticalPadding(BuildContext context, double designPadding) {
    return EdgeInsets.symmetric(vertical: height(context, designPadding));
  }

  // 전체 패딩 스케일링
  static EdgeInsets padding(BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    if (all != null) {
      return EdgeInsets.all(width(context, all));
    }
    return EdgeInsets.only(
      left: left != null ? width(context, left) : (horizontal ?? 0),
      right: right != null ? width(context, right) : (horizontal ?? 0),
      top: top != null ? height(context, top) : (vertical ?? 0),
      bottom: bottom != null ? height(context, bottom) : (vertical ?? 0),
    );
  }

  // SizedBox 높이 스케일링
  static SizedBox verticalSpace(BuildContext context, double designHeight) {
    return SizedBox(height: height(context, designHeight));
  }

  // SizedBox 너비 스케일링
  static SizedBox horizontalSpace(BuildContext context, double designWidth) {
    return SizedBox(width: width(context, designWidth));
  }

  // BorderRadius 스케일링
  static BorderRadius borderRadius(BuildContext context, double designRadius) {
    return BorderRadius.circular(width(context, designRadius));
  }

  // 최소/최대 크기 제한 (너무 작거나 크게 변하지 않도록)
  static double constrainedWidth(BuildContext context, double designWidthValue, {
    double? min,
    double? max,
  }) {
    final calculated = width(context, designWidthValue);
    if (min != null && calculated < min) return min;
    if (max != null && calculated > max) return max;
    return calculated;
  }

  static double constrainedHeight(BuildContext context, double designHeightValue, {
    double? min,
    double? max,
  }) {
    final calculated = height(context, designHeightValue);
    if (min != null && calculated < min) return min;
    if (max != null && calculated > max) return max;
    return calculated;
  }

  // 텍스트 스타일 생성 (반응형 폰트 크기)
  static TextStyle textStyle(BuildContext context, {
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontSize: ResponsiveHelper.fontSize(context, fontSize),
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }

  // 화면이 작은지 확인 (모바일)
  static bool isSmallScreen(BuildContext context) {
    return screenWidth(context) < 360;
  }

  // 화면이 큰지 확인 (태블릿)
  static bool isLargeScreen(BuildContext context) {
    return screenWidth(context) > 600;
  }

  // 화면이 매우 큰지 확인 (데스크톱)
  static bool isVeryLargeScreen(BuildContext context) {
    return screenWidth(context) > 1200;
  }
}

