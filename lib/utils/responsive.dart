import 'package:flutter/material.dart';

class Responsive {
  static const double mobileMaxWidth = 600.0;
  static const double tabletMaxWidth = 1024.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileMaxWidth &&
        MediaQuery.of(context).size.width < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMaxWidth;
  }

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileMaxWidth) return 16.0;
    if (width < tabletMaxWidth) return 24.0;
    return 32.0;
  }

  static double contentMaxWidth(BuildContext context, {double defaultMaxWidth = 1200.0}) {
    if (isMobile(context)) return double.infinity;
    return defaultMaxWidth;
  }

  // Constrains UI forms to prevent ridiculous stretching
  static Widget constrainedForm(BuildContext context, Widget child, {double maxWidth = 420.0}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  // Very slight font scaling if ever needed, though usually standard fonts are fine
  static double getFontSize(BuildContext context, double baseSize) {
    if (isDesktop(context)) return baseSize + 2.0;
    if (isTablet(context)) return baseSize + 1.0;
    return baseSize;
  }
}
