import 'package:flutter/material.dart';

/// 김치 색(고춧가루 붉은빛)을 시드로 쓴다.
const _seed = Color(0xFFC8322B);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

/// 랭킹 1~3위 강조색
Color rankColor(int rank, ColorScheme scheme) => switch (rank) {
  1 => const Color(0xFFD4A017),
  2 => const Color(0xFF9AA0A6),
  3 => const Color(0xFFB07A4B),
  _ => scheme.onSurfaceVariant,
};
