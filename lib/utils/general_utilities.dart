import 'dart:ui';

Color hexToColor(String hexCode) {
  return Color(int.parse(hexCode.replaceAll('#', '0xFF')));
}
