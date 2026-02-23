import 'package:flutter/material.dart';

/// 반응형 레이아웃·스타일 유틸
///
/// [로직 흐름]
/// 1. 기준: designWidth 390, designHeight 844 (디자인 시안)
/// 2. width(context, v): (v / 390) * 실제 너비 → 디자인 px를 실제 px로 변환
/// 3. height(context, v): (v / 844) * 실제 높이
/// 4. fontSize: width 비율로 폰트 스케일
/// 5. padding, verticalSpace, horizontalSpace, borderRadius: 동일 비율 적용
/// 6. textStyle: fontSize + color, fontWeight 등 조합
class ResponsiveHelper {
  static const double designWidth = 390.0;
  static const double designHeight = 844.0;

  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double width(BuildContext context, double designWidthValue) {
    final w = screenWidth(context);
    return (designWidthValue / designWidth) * w;
  }

  static double height(BuildContext context, double designHeightValue) {
    final h = screenHeight(context);
    return (designHeightValue / designHeight) * h;
  }

  static double fontSize(BuildContext context, double designFontSize) {
    final w = screenWidth(context);
    final scale = w / designWidth;
    return designFontSize * scale;
  }

  static EdgeInsets horizontalPadding(BuildContext context, double designPadding) {
    return EdgeInsets.symmetric(horizontal: width(context, designPadding));
  }

  static EdgeInsets verticalPadding(BuildContext context, double designPadding) {
    return EdgeInsets.symmetric(vertical: height(context, designPadding));
  }

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

  static SizedBox verticalSpace(BuildContext context, double designHeight) {
    return SizedBox(height: height(context, designHeight));
  }

  static SizedBox horizontalSpace(BuildContext context, double designWidth) {
    return SizedBox(width: width(context, designWidth));
  }

  static BorderRadius borderRadius(BuildContext context, double designRadius) {
    return BorderRadius.circular(width(context, designRadius));
  }

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
}
