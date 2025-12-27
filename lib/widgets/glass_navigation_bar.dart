import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../utils/responsive_helper.dart';


class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final PageController pageController;

  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    final double barHeight = ResponsiveHelper.height(context, 64);
    final double barRadius = ResponsiveHelper.width(context, 28);
    const double widthFactor = 0.90; // 90%


    return SizedBox(
      height: ResponsiveHelper.height(context, 110),
      child: Stack(
        children: [
          Positioned(
            bottom: ResponsiveHelper.height(context, 25), // 살짝 위로 이동
            left: ResponsiveHelper.width(context, 8),
            right: ResponsiveHelper.width(context, 8),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: SizedBox(
                  height: barHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double fullWidth = constraints.maxWidth;
                      final double horizontalPadding = ResponsiveHelper.width(context, 8);
                      final double innerWidth = fullWidth - horizontalPadding * 2;
                      const int tabsCount = 5;
                      final double segment = innerWidth / tabsCount;
                      final double capsuleWidth = ResponsiveHelper.width(context, 70);
                      final double capsuleHeight = ResponsiveHelper.height(context, 56);

                      return AnimatedBuilder(
                        animation: pageController,
                        builder: (context, _) {
                          double page = currentIndex.toDouble();
                          if (pageController.hasClients) {
                            final p = pageController.page;
                            if (p != null) page = p.clamp(0, (tabsCount - 1).toDouble());
                          }
                          final double centerX = horizontalPadding + (page + 0.5) * segment;
                          final double leftForCapsule = centerX - (capsuleWidth / 2);
                          final bool isDark = Theme.of(context).brightness == Brightness.dark;
                          final Color capsuleFill =
                              isDark ? const Color.fromRGBO(255, 255, 255, 0.12) : const Color.fromRGBO(0, 0, 0, 0.12);

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(barRadius),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: ResponsiveHelper.width(context, 1.5),
                                      sigmaY: ResponsiveHelper.height(context, 1.5),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              // 웹에서는 LiquidGlassLayer 대신 Container 사용
                              kIsWeb
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color.fromARGB(29, 255, 255, 255)
                                            : const Color.fromARGB(37, 26, 26, 26),
                                        borderRadius: BorderRadius.circular(barRadius),
                                      ),
                                      child: const SizedBox.expand(),
                                    )
                                  : LiquidGlassLayer(
                                      settings: LiquidGlassSettings(
                                        thickness: ResponsiveHelper.width(context, 10),
                                        glassColor: isDark
                                            ? const Color.fromARGB(29, 255, 255, 255)
                                            : const Color.fromARGB(37, 26, 26, 26),
                                        lightIntensity: 1.6,
                                        ambientStrength: 0.85,
                                        saturation: 0.92,
                                        lightness: 1.02,
                                      ),
                                      child: Stack(
                                        children: [
                                          LiquidGlass.inLayer(
                                            shape: LiquidRoundedSuperellipse(
                                              borderRadius: Radius.circular(barRadius),
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        ],
                                      ),
                                    ),

                              Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: _buildNavItem(context: context, index: 0, icon: Icons.directions_bus, label: '버스', isSelected: currentIndex == 0, iconSize: 30)),
                                      Expanded(child: _buildNavItem(context: context, index: 1, iconPath: 'assets/images/timetable_logo.svg', label: '시간표', isSelected: currentIndex == 1)),
                                      Expanded(child: _buildNavItem(context: context, index: 2, iconPath: 'assets/images/home_logo.svg', label: '홈', isSelected: currentIndex == 2)),
                                      Expanded(child: _buildNavItem(context: context, index: 3, iconPath: 'assets/images/lunch_logo.svg', label: '급식', isSelected: currentIndex == 3)),
                                      Expanded(child: _buildNavItem(context: context, index: 4, iconPath: 'assets/images/my_logo.svg', label: '마이', isSelected: currentIndex == 4)),
                                    ],
                                  ),
                                ),
                              ),

                              Positioned(
                                left: leftForCapsule,
                                top: (barHeight - capsuleHeight) / 2,
                                width: capsuleWidth,
                                height: capsuleHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: capsuleFill,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 20)),
                                    border: Border.all(
                                      color: const Color.fromRGBO(255, 255, 255, 0.35),
                                      width: ResponsiveHelper.width(context, 1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    String? iconPath,
    IconData? icon,
    required String label,
    required bool isSelected,
    double? iconSize,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Center(
        child: Container(
          width: ResponsiveHelper.width(context, 66),
          height: ResponsiveHelper.height(context, 56),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 50)),
            color: Colors.transparent, // 선택 여부와 무관하게 회색 배경 제거
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: ResponsiveHelper.width(context, 25),
                    height: ResponsiveHelper.height(context, 25),
                    child: Builder(builder: (innerContext) {
                      final bool isDark = Theme.of(innerContext).brightness == Brightness.dark;
                      final Color unselected = isDark
                          ? const Color.fromRGBO(230, 230, 230, 0.75)
                          : const Color.fromRGBO(48, 48, 46, 0.60);
                      
                      if (icon != null) {
                        final double finalIconSize = iconSize ?? ResponsiveHelper.width(innerContext, 25);
                        Widget iconWidget = Icon(
                          icon,
                          size: finalIconSize,
                          color: isSelected
                              ? const Color.fromRGBO(255, 197, 30, 1)
                              : unselected,
                        );
                        
                        if (icon == Icons.directions_bus) {
                          return Transform.translate(
                            offset: Offset(
                              -ResponsiveHelper.width(innerContext, 2.4),
                              -ResponsiveHelper.height(innerContext, 3),
                            ),
                            child: iconWidget,
                          );
                        }
                        
                        return iconWidget;
                      } else {
                        return SvgPicture.asset(
                          iconPath!,
                          semanticsLabel: label,
                          colorFilter: ColorFilter.mode(
                            isSelected
                                ? const Color.fromRGBO(255, 197, 30, 1)
                                : unselected,
                            BlendMode.srcIn,
                          ),
                        );
                      }
                    }),
                  ),
                  ResponsiveHelper.verticalSpace(context, 4),
                  Builder(builder: (innerContext) {
                    final bool isDark = Theme.of(innerContext).brightness == Brightness.dark;
                    final Color unselected = isDark
                        ? const Color.fromRGBO(230, 230, 230, 0.75)
                        : const Color.fromRGBO(48, 48, 46, 0.60);
                    return Text(
                      label,
                      textAlign: TextAlign.center,
                      style: ResponsiveHelper.textStyle(
                        innerContext,
                        fontSize: 10,
                        color: isSelected
                            ? const Color.fromRGBO(255, 197, 30, 1)
                            : unselected,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

