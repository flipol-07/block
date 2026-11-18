import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Fondo de Block: casi negro con dos luces suaves (ambar y azul) que dan
/// profundidad al cristal que va encima.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: BlockColors.background),
      child: Stack(
        children: [
          const _Glow(alignment: Alignment(-1.1, -0.9), color: BlockColors.accent, opacity: 0.20),
          const _Glow(alignment: Alignment(1.2, 0.2), color: BlockColors.blue, opacity: 0.16),
          const _Glow(alignment: Alignment(-0.6, 1.2), color: BlockColors.violet, opacity: 0.10),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.alignment, required this.color, required this.opacity});

  final Alignment alignment;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: alignment,
                radius: 0.9,
                colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );
}

/// Scaffold transparente sobre [GlassBackground], con barra superior de cristal.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({super.key, this.title, this.actions, required this.body});

  final Widget? title;
  final List<Widget>? actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: title == null && actions == null
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                title: title,
                actions: actions,
              ),
        body: body,
      ),
    );
  }
}

/// Tarjeta de cristal esmerilado: desenfoque de lo que hay detras, relleno
/// blanco muy tenue y un borde de 1 px que hace de reflejo.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tint ?? Colors.white).withValues(alpha: 0.10),
                  (tint ?? Colors.white).withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Control segmentado de cristal (como el de iOS) para elegir una opcion.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: o == selected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label(o),
                    style: TextStyle(
                      fontWeight: o == selected ? FontWeight.w600 : FontWeight.w500,
                      color: o == selected ? BlockColors.text : BlockColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
