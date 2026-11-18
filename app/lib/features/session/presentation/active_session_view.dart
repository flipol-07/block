import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/blocker/blocker.dart';
import '../../../shared/ui/glass.dart';
import '../../../shared/ui/theme.dart';
import '../application/session_controller.dart';
import '../domain/focus_session.dart';
import 'emergency_exit_screen.dart';

/// Cuenta atras de la sesion en curso: un disco de cristal con el anillo de
/// progreso alrededor.
class ActiveSessionView extends ConsumerStatefulWidget {
  const ActiveSessionView({super.key, required this.session});

  final FocusSession session;

  @override
  ConsumerState<ActiveSessionView> createState() => _ActiveSessionViewState();
}

class _ActiveSessionViewState extends ConsumerState<ActiveSessionView> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String get _message {
    if (Blocker.isAndroid) return 'El móvil está bloqueado hasta que termine la sesión.';
    if (widget.session.singleWindow) return 'Modo una sola ventana.\nCtrl+Shift+B abre Block.';
    return 'Las apps y webs de tu lista están bloqueadas.';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(sessionControllerProvider.notifier);
    final s = widget.session;
    final remaining = s.remainingMs(controller.nowMs());
    final progress = (1 - remaining / s.totalMs).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    color: BlockColors.accent,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                GlassCard(
                  radius: 120,
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatRemaining(remaining),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w200,
                            letterSpacing: -2,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'BLOCK ACTIVO',
                          style: TextStyle(
                            color: BlockColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyExitScreen()),
            ),
            child: const Text('Salida de emergencia', style: TextStyle(color: BlockColors.muted)),
          ),
        ],
      ),
    );
  }
}
