import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/blocker/blocker.dart';
import '../../shared/providers.dart';
import '../../shared/ui/theme.dart';
import '../../shared/ui/glass.dart';

/// Guia de permisos de Android. Cada paso explica para que sirve, porque
/// la queja numero 3 de los bloqueadores es "el movil me quito el permiso".
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> with WidgetsBindingObserver {
  AndroidPermissions? _p;

  Blocker get _blocker => ref.read(blockerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = await _blocker.permissions();
    if (mounted) setState(() => _p = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return GlassScaffold(
      title: const Text('Permisos'),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Step(
                  done: p.accessibility,
                  title: '1. Servicio de accesibilidad',
                  body: 'Es lo que muestra la pantalla de Block encima de todo '
                      'durante una sesión. Block no lee ni guarda lo que '
                      'escribes: solo mira qué app está abierta.',
                  action: 'Activar',
                  onTap: _blocker.openAccessibilitySettings,
                ),
                if (!p.accessibility) const _RestrictedHint(),
                _Step(
                  done: p.deviceAdmin,
                  title: '2. Proteger contra desinstalación',
                  body: 'Mientras esté activo no se puede desinstalar Block. '
                      'Puedes quitarlo cuando quieras fuera de una sesión.',
                  action: 'Activar',
                  onTap: _blocker.requestDeviceAdmin,
                ),
                _Step(
                  done: p.batteryUnrestricted,
                  title: '3. Sin restricciones de batería',
                  body: 'Evita que el sistema cierre Block para ahorrar batería. '
                      'En Xiaomi, Samsung u Oppo revisa también "Inicio '
                      'automático" en la información de la app.',
                  action: 'Permitir',
                  onTap: _blocker.requestBatteryExemption,
                ),
              ],
            ),
    );
  }
}

class _RestrictedHint extends ConsumerWidget {
  const _RestrictedHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si Android dice "Ajuste restringido": abre la información de la '
              'app, pulsa ⋮ arriba a la derecha y elige "Permitir ajustes '
              'restringidos". Después vuelve a intentarlo.',
              style: TextStyle(color: BlockColors.muted),
            ),
            TextButton(
              onPressed: ref.read(blockerProvider).openAppDetails,
              child: const Text('Abrir información de la app'),
            ),
          ],
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final bool done;
  final String title;
  final String body;
  final String action;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? BlockColors.accent : BlockColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(color: BlockColors.muted)),
              if (!done) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: onTap, child: Text(action)),
              ],
            ],
          ),
        ),
      );
}
