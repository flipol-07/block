import 'package:flutter/material.dart';

/// Block es oscuro y sobrio a proposito: una pantalla de concentracion no
/// debe competir por la atencion. Cristal esmerilado al estilo Apple sobre
/// un fondo casi negro con luces suaves.
class BlockColors {
  static const background = Color(0xFF07080B);
  static const surface = Color(0xFF15171C);
  static const surfaceHigh = Color(0xFF1F2229);
  static const accent = Color(0xFFE9C46A);
  static const blue = Color(0xFF5B8CFF);
  static const violet = Color(0xFF9B6BFF);
  static const text = Color(0xFFF5F3EE);
  static const muted = Color(0xFF9A9EA8);
  static const danger = Color(0xFFFF6B5B);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BlockColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: BlockColors.accent,
    onPrimary: const Color(0xFF1A1405),
    surface: BlockColors.background,
    surfaceContainer: BlockColors.surface,
    surfaceContainerHigh: BlockColors.surfaceHigh,
    error: BlockColors.danger,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme.apply(bodyColor: BlockColors.text, displayColor: BlockColors.text).copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: BlockColors.text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0xFF34C759)
            : Colors.white.withValues(alpha: 0.12),
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: BlockColors.accent,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
      thumbColor: Colors.white,
      overlayColor: BlockColors.accent.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      selectedColor: Colors.white.withValues(alpha: 0.18),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: BlockColors.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.08)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BlockColors.accent),
      ),
    ),
  );
}

/// Numeros de ancho fijo: la cuenta atras no "baila" al cambiar los digitos.
const tabularFigures = [FontFeature.tabularFigures()];

String formatRemaining(int ms) {
  final total = (ms / 1000).ceil();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
