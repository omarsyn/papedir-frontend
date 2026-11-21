import 'package:flutter/material.dart';

/// Medidas comunes del diseño (bordes redondeados y espacios).
abstract final class Disenio {
  static const radio = 20.0;
  static const radioChico = 14.0;
  static const margen = 16.0;
}

/// Tema de PaPedir: fondo gris claro, tarjetas blancas sin sombra fuerte,
/// botones redondos y títulos gruesos. [semilla] es el color de cada app.
ThemeData construirTema(Color semilla, Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  var esquema = ColorScheme.fromSeed(seedColor: semilla, brightness: brillo);
  // En modo claro se respeta el color exacto de la marca.
  if (!oscuro) {
    esquema = esquema.copyWith(primary: semilla, onPrimary: Colors.white);
  }
  final fondo = oscuro ? const Color(0xFF111318) : const Color(0xFFF5F6F8);
  final tarjeta = oscuro ? const Color(0xFF1C1F26) : Colors.white;
  final campo = oscuro ? const Color(0xFF22262E) : Colors.white;

  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  final t = base.textTheme;
  final texto = t.copyWith(
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  OutlineInputBorder borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Disenio.radioChico),
        borderSide: BorderSide(color: color, width: ancho),
      );

  return base.copyWith(
    scaffoldBackgroundColor: fondo,
    textTheme: texto,
    appBarTheme: AppBarTheme(
      backgroundColor: fondo,
      foregroundColor: esquema.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: texto.titleLarge?.copyWith(color: esquema.onSurface),
    ),
    cardTheme: CardThemeData(
      color: tarjeta,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Disenio.radio),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: campo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde(esquema.outlineVariant),
      enabledBorder: borde(esquema.outlineVariant),
      focusedBorder: borde(esquema.primary, 2),
      errorBorder: borde(esquema.error),
      focusedErrorBorder: borde(esquema.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      shape: const StadiumBorder(),
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tarjeta,
      selectedColor: esquema.primaryContainer,
      side: BorderSide(color: esquema.outlineVariant),
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: esquema.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Disenio.radioChico),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: esquema.outlineVariant.withValues(alpha: 0.5),
      space: 24,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Disenio.radioChico),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tarjeta,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: esquema.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontSize: 12,
          fontWeight: estados.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: estados.contains(WidgetState.selected)
              ? esquema.primary
              : esquema.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected)
              ? esquema.primary
              : esquema.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tarjeta,
      indicatorColor: esquema.primaryContainer,
      selectedIconTheme: IconThemeData(color: esquema.primary),
      selectedLabelTextStyle: TextStyle(
        color: esquema.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      labelColor: esquema.primary,
      indicatorColor: esquema.primary,
      dividerColor: Colors.transparent,
    ),
  );
}
