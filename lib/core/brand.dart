import 'package:flutter/painting.dart';

/// Product identity. Change the name here (and in the platform manifests
/// listed in the README) to rebrand the app.
abstract final class Brand {
  static const name = 'Burrow';
  static const tagline = 'Every file, right where you left it.';

  /// Signature accent: a warm ember orange.
  static const ember = Color(0xFFF2542D);
  static const emberLight = Color(0xFFFF8A4C);

  /// Deep ink used for the icon, splash screens and dark surfaces.
  static const ink = Color(0xFF15121F);
  static const inkLight = Color(0xFF2B2544);

  /// The glow inside the burrow doorway.
  static const glow = Color(0xFFFFC978);

  static const fontFamily = 'PlusJakartaSans';
}
