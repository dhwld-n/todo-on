import 'package:flutter/material.dart';

// Blue, yellow and purple: the pens. Structure is drawn in ink (see
// widgets/paper.dart), color only where it means something.
const kAccentBlue = Color(0xFF2373F4);
const kAccentYellow = Color(0xFFFFD749);
const kAccentPurple = Color(0xFF705EFF);

const kSeedColor = kAccentBlue;
// The diary: light grid paper, a dark page with a faint white grid.
const kLavenderBg = Color(0xFFEEEEEE);
const kPaperLight = Color(0xFFFBFAF6);
const kEdgeLight = Color(0xFF2A2A2A);
const kDarkBg = Color(0xFF2C2C2C);
const kDarkSurface = Color(0xFF373737);
const kDarkChipBg = Color(0xFF424242);
// Not the surface: an input on a card must stay visible as a box.
const kDarkInputFill = Color(0xFF2F2F2F);
const kDarkInk = Color(0xFFF1EFE9);
const kEdgeDark = Color(0xFFDAD7D0);
const kInkText = Color(0xFF2A2A2A);
const kCardBorderLight = Color(0xFFD3D3D3);

ThemeData buildLightTheme() => _diaryInk(_baseLight(), edge: kEdgeLight);

ThemeData _baseLight() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: kSeedColor,
        brightness: Brightness.light,
      ).copyWith(
        surface: kPaperLight,
        onSurface: kInkText,
        primary: kAccentBlue,
        onPrimary: Colors.white,
        secondary: kAccentPurple,
        onSecondary: Colors.white,
        tertiary: kAccentYellow,
        onTertiary: kInkText,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'GriunFromsol',
    scaffoldBackgroundColor: kLavenderBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: kInkText,
      titleTextStyle: TextStyle(
        fontFamily: 'GriunFromsol',
        color: kInkText,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: kPaperLight,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kLavenderBg,
      selectedColor: colorScheme.primary,
      secondarySelectedColor: colorScheme.primary,
      disabledColor: kLavenderBg,
      labelStyle: const TextStyle(
        fontFamily: 'OwnglyphParkDaHyun',
        fontWeight: FontWeight.w600,
        color: kInkText,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'OwnglyphParkDaHyun',
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kLavenderBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFD3E5F8),
      thickness: 1,
    ),
  );
}

ThemeData buildDarkTheme() => _diaryInk(_baseDark(), edge: kEdgeDark);

ThemeData _baseDark() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: kSeedColor,
        brightness: Brightness.dark,
      ).copyWith(
        surface: kDarkSurface,
        onSurface: kDarkInk,
        secondary: kAccentPurple,
        onSecondary: Colors.white,
        tertiary: kAccentYellow,
        onTertiary: kInkText,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'GriunFromsol',
    scaffoldBackgroundColor: kDarkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'GriunFromsol',
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: kDarkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kDarkChipBg,
      selectedColor: colorScheme.primary,
      secondarySelectedColor: colorScheme.primary,
      labelStyle: const TextStyle(
        fontFamily: 'OwnglyphParkDaHyun',
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'OwnglyphParkDaHyun',
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkInputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: const StadiumBorder(),
    ),
  );
}

/// Controls, dialogs and sheets drawn in ink to match the diary pages: an
/// inked edge, the chosen one filled in ink, paper behind. Color is left to
/// what means something (category, today, unread).
ThemeData _diaryInk(ThemeData t, {required Color edge}) {
  final paper = t.colorScheme.surface;
  final ink = t.colorScheme.onSurface;
  final line = BorderSide(color: edge, width: 1.5);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );
  final page = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: line,
  );
  WidgetStateProperty<Color> pick(Color on, Color off) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? on : off,
      );
  OutlineInputBorder box(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: side,
  );
  return t.copyWith(
    chipTheme: t.chipTheme.copyWith(
      backgroundColor: paper,
      selectedColor: edge,
      secondarySelectedColor: edge,
      disabledColor: paper,
      checkmarkColor: paper,
      labelStyle: t.chipTheme.labelStyle?.copyWith(color: ink),
      secondaryLabelStyle: t.chipTheme.secondaryLabelStyle?.copyWith(
        color: paper,
      ),
      side: line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    // A box drawn in pen; its edge is what keeps a field visible on a card
    // of the same paper.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      border: box(line),
      enabledBorder: box(line),
      focusedBorder: box(BorderSide(color: t.colorScheme.primary, width: 2)),
      disabledBorder: box(BorderSide(color: t.dividerColor, width: 1.5)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: line,
        shape: rounded,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: edge,
        foregroundColor: paper,
        shape: rounded,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: pick(edge, Colors.transparent),
        foregroundColor: pick(paper, ink),
        side: WidgetStatePropertyAll(line),
        shape: WidgetStatePropertyAll(rounded),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: pick(paper, edge),
      trackColor: pick(edge, paper),
      trackOutlineColor: WidgetStatePropertyAll(edge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: edge,
      foregroundColor: paper,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: page,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: paper,
      modalBackgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        side: line,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: line,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: page,
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: paper, shape: page),
  );
}
