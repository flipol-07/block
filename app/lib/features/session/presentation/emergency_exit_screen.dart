import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/config.dart';
import '../../../shared/ui/theme.dart';
import '../../../shared/ui/glass.dart';
import '../application/session_controller.dart';

/// Salida de emergencia con friccion: esperar respirando, escribir una frase
/// y dar un motivo. La friccion con opcion de abandonar es lo que funciona
/// (one sec, PNAS 2023); una contrasena no.
class EmergencyExitScreen extends ConsumerStatefulWidget {
  const EmergencyExitScreen({super.key});

  @override
  ConsumerState<EmergencyExitScreen> createState() => _EmergencyExitScreenState();
}

class _EmergencyExitScreenState extends ConsumerState<EmergencyExitScreen>
    with SingleTickerProviderStateMixin {
  static const reasons = [
    'Ya he terminado de estudiar',
    'Urgencia real',
    'Trabajo o llamada importante',
    'No puedo más hoy',
  ];

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
  late final Timer _timer;
  int _secondsLeft = AppConfig.exitWaitSeconds;
  final _phrase = TextEditingController();
  String? _reason;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft--);
    });
    _phrase.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    _breath.dispose();
    _phrase.dispose();
    super.dispose();
  }

  bool get _phraseOk =>
      _phrase.text.trim().toLowerCase() == AppConfig.exitPhrase.toLowerCase();

  Future<void> _confirm() async {
    setState(() => _sending = true);
    await ref.read(sessionControllerProvider.notifier).emergencyExit(_reason!);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _secondsLeft > 0;
    return GlassScaffold(
      title: const Text('Salida de emergencia'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: waiting ? _breathing() : _form(),
        ),
      ),
    );
  }

  List<Widget> _breathing() => [
        const SizedBox(height: 24),
        Center(
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, _) => Container(
              width: 120 + 80 * _breath.value,
              height: 120 + 80 * _breath.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BlockColors.accent.withValues(alpha: 0.12 + 0.18 * _breath.value),
              ),
              alignment: Alignment.center,
              child: Text(
                '$_secondsLeft',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w300),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _breath.status == AnimationStatus.forward ? 'Inspira…' : 'Espira…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Respira un minuto antes de decidir. Si sigues queriendo salir, '
          'podrás hacerlo después.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BlockColors.muted),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vuelvo a estudiar'),
        ),
      ];

  List<Widget> _form() => [
        Text('Escribe para confirmar:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '"${AppConfig.exitPhrase}"',
          style: const TextStyle(color: BlockColors.accent, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(controller: _phrase, autocorrect: false),
        const SizedBox(height: 24),
        Text('¿Por qué?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in reasons)
              ChoiceChip(
                label: Text(r),
                selected: _reason == r,
                onSelected: (_) => setState(() => _reason = r),
              ),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vuelvo a estudiar'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: BlockColors.danger,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: _phraseOk && _reason != null && !_sending ? _confirm : null,
          child: const Text('Terminar la sesión en todos mis dispositivos'),
        ),
      ];
}
