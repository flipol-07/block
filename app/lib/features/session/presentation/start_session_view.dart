import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../shared/blocker/blocker.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/glass.dart';
import '../../../shared/ui/theme.dart';
import '../application/session_controller.dart';

/// Elegir duracion y modo, y empezar.
class StartSessionView extends ConsumerStatefulWidget {
  const StartSessionView({super.key});

  @override
  ConsumerState<StartSessionView> createState() => _StartSessionViewState();
}

class _StartSessionViewState extends ConsumerState<StartSessionView> {
  static const presets = [25, 50, 90];
  int _minutes = 50;
  bool _singleWindow = false;
  OpenWindow? _window;
  List<OpenWindow> _windows = [];

  Future<void> _loadWindows() async {
    final list = await ref.read(blockerProvider).listWindows();
    setState(() {
      _windows = list;
      if (_window != null && !list.any((w) => w.handle == _window!.handle)) {
        _window = null;
      }
    });
  }

  Future<void> _start() async {
    await ref.read(sessionControllerProvider.notifier).start(
          minutes: _minutes,
          singleWindow: _singleWindow,
          allowedWindow: _window?.handle,
        );
    // En ventana unica Block se aparta para que se vea (y se pueda clicar)
    // la ventana de estudio. Ctrl+Shift+B lo vuelve a abrir.
    if (_singleWindow && Blocker.isWindows) await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(sessionControllerProvider).loading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('¿Cuánto vas a estudiar?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        _durationCard(),
        const SizedBox(height: 12),
        GlassSegmented<int>(
          options: presets,
          selected: presets.contains(_minutes) ? _minutes : null,
          label: (m) => '$m min',
          onChanged: (m) => setState(() => _minutes = m),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(Blocker.isWindows ? 'Una sola ventana' : 'Una sola ventana en el PC'),
                subtitle: const Text(
                  'Todo lo demás queda tapado hasta acabar.',
                  style: TextStyle(color: BlockColors.muted),
                ),
                value: _singleWindow,
                onChanged: (v) {
                  setState(() => _singleWindow = v);
                  if (v && Blocker.isWindows) _loadWindows();
                },
              ),
              if (_singleWindow && Blocker.isWindows) _windowPicker(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : _start,
          child: const Text('Empezar a estudiar'),
        ),
        const SizedBox(height: 14),
        Text(
          Blocker.isAndroid
              ? 'El móvil quedará bloqueado (salvo llamadas de emergencia), '
                  'y también tu PC si usa la misma cuenta.'
              : 'Tu móvil quedará bloqueado si usa la misma cuenta.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: BlockColors.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _durationCard() => GlassCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_minutes',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -2,
                    fontFeatures: tabularFigures,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('min', style: TextStyle(fontSize: 18, color: BlockColors.muted)),
              ],
            ),
            Slider(
              min: 1,
              max: 240,
              divisions: 239,
              value: _minutes.toDouble(),
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
          ],
        ),
      );

  Widget _windowPicker() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _window == null
                  ? 'Al empezar, Block se esconde: haz clic en la ventana donde '
                      'vas a estudiar y todo lo demás quedará tapado.'
                  : 'Solo podrás usar "${_window!.title}" (y sus diálogos).',
              style: const TextStyle(color: BlockColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _window?.handle,
                    isExpanded: true,
                    hint: const Text('O elígela ahora (opcional)'),
                    items: [
                      for (final w in _windows)
                        DropdownMenuItem(
                          value: w.handle,
                          child: Text('${w.title} · ${w.exe}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (h) => setState(
                      () => _window = _windows.firstWhere((w) => w.handle == h),
                    ),
                  ),
                ),
                IconButton(onPressed: _loadWindows, icon: const Icon(Icons.refresh)),
              ],
            ),
          ],
        ),
      );
}
