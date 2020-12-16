import 'package:flutter/material.dart';

export 'package:provider/provider.dart';

extension ColorExtensions on Color {
  String get hexValue =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Color fromHex(String hex) =>
      Color(int.parse(hex.replaceFirst('#', ''), radix: 16) + 0xFF000000);
}

extension BrightnessExtensions on Brightness {
  Brightness get invert =>
      this == Brightness.light ? Brightness.dark : Brightness.light;
}