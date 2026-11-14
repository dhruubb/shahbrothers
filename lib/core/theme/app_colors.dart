import 'package:flutter/material.dart';

/// Shah Brothers palette: deep maroon, ivory, cream and a restrained gold.
class AppColors {
  const AppColors._();

  static const maroon900 = Color(0xFF3E0A17);
  static const maroon800 = Color(0xFF55101F);
  static const maroon = Color(0xFF6E1423);
  static const maroon500 = Color(0xFF8E2A3B);
  static const maroon100 = Color(0xFFF4E3E3);

  static const ivory = Color(0xFFFFFCF6);
  static const cream = Color(0xFFF7EFE2);
  static const sand = Color(0xFFEADCC6);
  static const card = Color(0xFFFFFDF9);
  static const border = Color(0xFFE9DDCB);

  static const gold = Color(0xFFB8893A);
  static const goldDeep = Color(0xFF8C6A2A); // gold that passes contrast on ivory
  static const goldLight = Color(0xFFE9D3A1);
  static const goldPale = Color(0xFFF6EBD2);

  static const ink = Color(0xFF2A1B1E);
  static const inkMuted = Color(0xFF6F5E5A);
  static const inkSoft = Color(0xFF9B8C86);

  static const success = Color(0xFF2F7D4F);
  static const successBg = Color(0xFFE5F2EA);
  static const warning = Color(0xFFA8691B);
  static const warningBg = Color(0xFFFBEFD9);
  static const error = Color(0xFFB3261E);
  static const errorBg = Color(0xFFFBE7E5);

  /// Series colours for charts (maroon first, then harmonious accents).
  static const chart = [
    maroon,
    gold,
    Color(0xFF2E6F6A), // peacock teal
    Color(0xFFC0562F), // rust
    Color(0xFF5A4A8A), // jamun
    Color(0xFF7D8B3A), // mehendi
    Color(0xFFB04F78), // rani
  ];
}
