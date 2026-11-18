import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import '../../shared/ui/theme.dart';
import '../../shared/ui/glass.dart';
import 'block_rule.dart';

/// Que se bloquea en el PC: apps (ejecutables) y webs.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  List<BlockRule> _rules = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(rulesRepositoryProvider);
    _rules = repo.cached();
    repo.refresh().then((r) {
      if (mounted) setState(() => _rules = r);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = 'No se pudo sincronizar: $e');
    });
  }

  Future<void> _mutate(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      _error = 'No se pudo guardar en la nube: $e';
    }
    if (mounted) setState(() => _rules = ref.read(rulesRepositoryProvider).cached());
  }

  Future<void> _add(String kind) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == 'app' ? 'Bloquear app del PC' : 'Bloquear web'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: kind == 'app' ? 'whatsapp.exe' : 'youtube.com',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final rule = BlockRule.parse(kind, value);
    if (rule == null) {
      setState(() => _error = '"$value" no es válido.');
      return;
    }
    await _mutate(() => ref.read(rulesRepositoryProvider).save(rule));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rulesRepositoryProvider);
    return GlassScaffold(
      title: const Text('Qué se bloquea'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'En el móvil se bloquea todo salvo llamadas. Aquí eliges qué se '
            'bloquea en el PC.',
            style: TextStyle(color: BlockColors.muted),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: BlockColors.danger)),
            ),
          for (final kind in ['app', 'site']) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    kind == 'app' ? 'Apps del PC' : 'Webs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _add(kind),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                ),
              ],
            ),
            GlassCard(
              child: Column(
                children: [
                  for (final r in _rules.where((r) => r.kind == kind))
                    SwitchListTile(
                      title: Text(r.value),
                      value: r.enabled,
                      onChanged: (v) => _mutate(() => repo.save(r.copyWith(enabled: v))),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _mutate(() => repo.remove(r)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Las webs se bloquean con la extensión de Block para Chrome/Edge.',
            style: TextStyle(color: BlockColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
