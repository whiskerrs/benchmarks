import 'package:dartnative/dartnative.dart';

/// Design tokens from spec/design/screens/Tokens.dc.html.
abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF4F1EC);
  static const skeleton = Color(0xFFEDE9E3);
  static const border = Color(0xFFE6E1D9);
  static const text = Color(0xFF1C1B19);
  static const textMuted = Color(0xFF6E6A63);
  static const sale = Color(0xFFB4361E);
  static const body = Color(0xFF3D3A35);
  static const bannerScrim = Color(0xB81C1B19); // text at 72%
  static const dotInactive = Color(0x401C1B19); // text at 25%
  static const white = Color(0xFFFFFFFF);
}

abstract final class AppText {
  static const screenTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const wordmark = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const sectionHeading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const cardTitle = TextStyle(
    fontSize: 14,
    height: 18 / 14,
    color: AppColors.text,
  );
  static const price = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const caption = TextStyle(fontSize: 13, color: AppColors.textMuted);
  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
}

abstract final class Insets {
  static const screen = 16.0;
}
