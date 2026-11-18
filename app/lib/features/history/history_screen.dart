import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import '../../shared/ui/theme.dart';
import '../../shared/ui/glass.dart';
import '../session/domain/focus_session.dart';

final historyProvider = FutureProvider.autoDispose<List<HistoryEntry>>(
  (ref) => ref.watch(sessionRepositoryProvider).history(),
);

/// Historial sin castigos: minutos estudiados, sesiones y salidas.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return GlassScaffold(
      title: const Text('Historial'),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (entries) => entries.isEmpty
            ? const Center(
                child: Text('Aún no hay sesiones.', style: TextStyle(color: BlockColors.muted)),
              )
            : _HistoryList(entries: entries),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<HistoryEntry> entries;

  int _minutesSince(DateTime from) => entries
      .where((e) => DateTime.fromMillisecondsSinceEpoch(e.startedAtMs).isAfter(from))
      .fold(0, (sum, e) => sum + e.minutes);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final exits = entries.where((e) => e.status == 'emergency_exit').length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _Stat(label: 'Hoy', value: _hours(_minutesSince(today))),
            _Stat(label: 'Esta semana', value: _hours(_minutesSince(week))),
            _Stat(label: 'Salidas', value: '$exits'),
          ],
        ),
        const SizedBox(height: 16),
        for (final e in entries) _EntryTile(entry: e),
      ],
    );
  }

  static String _hours(int minutes) =>
      minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: BlockColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontFeatures: tabularFigures),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(entry.startedAtMs);
    final exit = entry.status == 'emergency_exit';
    final date = '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    return ListTile(
      leading: Icon(
        exit ? Icons.logout : Icons.check_circle_outline,
        color: exit ? BlockColors.muted : BlockColors.accent,
      ),
      title: Text('${entry.minutes} min'),
      subtitle: Text(exit ? '$date · ${entry.reason ?? 'Salida de emergencia'}' : date),
    );
  }
}
