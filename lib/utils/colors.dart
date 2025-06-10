// utils/colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color grey = Colors.grey;

  // Accent colors
  static const Color blue = Colors.blue;

  // Custom shades
  static Color grey850 = Colors.grey[850]!;
  static Color grey900 = Colors.grey[900]!;
  static Color black87 = Colors.black87;

  // Status colors
  static const Color green = Colors.green;
  static const Color red = Colors.red;

  // Transparent variants
  static Color blueWithOpacity03 = Colors.blue.withOpacity(0.3);
  static Color blueWithOpacity01 = Colors.blue.withOpacity(0.1);
  static Color blackWithOpacity05 = Colors.black.withOpacity(0.5);
}

class ProfileColors {
  static const Color cardBackground = Colors.grey;
  static const Color textColor = Colors.white;
  static const Color fareTextColor = Colors.white;
}

class DriverProfileColors {
  static const Color iconColor = Colors.blue;
  static const Color borderColor = Colors.blue;
  static const Color titleColor = Color.fromARGB(255, 236, 236, 236);
  static const Color errorColor = Colors.red;
  static const Color cardBackground = Colors.grey;
  static const Color sectionTitleColor = Colors.white;
  static const Color infoTitleColor = Colors.grey;
  static const Color infoValueColor = Colors.white;
  static const Color earningsValueColor = Colors.blue;
}
