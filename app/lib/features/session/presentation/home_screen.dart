import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/blocker/blocker.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/glass.dart';
import '../../../shared/ui/theme.dart';
import '../../history/history_screen.dart';
import '../../rules/rules_screen.dart';
import '../../setup/setup_screen.dart';
import '../application/session_controller.dart';
import 'active_session_view.dart';
import 'start_session_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final session = state.session;
    final locked = session != null;
    return GlassScaffold(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 28,
              height: 28,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Block'),
        ],
      ),
      actions: locked ? null : _actions(context, ref),
      body: SafeArea(
        child: Column(
          children: [
            if (Blocker.isAndroid && !locked) const _PermissionsBanner(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: BlockColors.muted, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Expanded(
              child: state.loading && session == null
                  ? const Center(child: CircularProgressIndicator())
                  : session != null
                      ? ActiveSessionView(key: ValueKey(session.id), session: session)
                      : const StartSessionView(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) => [
        IconButton(
          tooltip: 'Qué se bloquea',
          icon: const Icon(Icons.block),
          onPressed: () => _open(context, const RulesScreen()),
        ),
        IconButton(
          tooltip: 'Historial',
          icon: const Icon(Icons.insights_outlined),
          onPressed: () => _open(context, const HistoryScreen()),
        ),
        if (Blocker.isAndroid)
          IconButton(
            tooltip: 'Permisos',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => _open(context, const SetupScreen()),
          ),
        if (ref.watch(supabaseProvider) != null)
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(localModeProvider.notifier).set(false);
              await ref.read(supabaseProvider)!.auth.signOut();
            },
          ),
      ];
}

/// Aviso en Android si falta algun permiso para que el bloqueo funcione.
class _PermissionsBanner extends ConsumerStatefulWidget {
  const _PermissionsBanner();

  @override
  ConsumerState<_PermissionsBanner> createState() => _PermissionsBannerState();
}

class _PermissionsBannerState extends ConsumerState<_PermissionsBanner>
    with WidgetsBindingObserver {
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final p = await ref.read(blockerProvider).permissions();
    if (mounted) setState(() => _missing = !p.allGranted);
  }

  @override
  Widget build(BuildContext context) {
    if (!_missing) return const SizedBox.shrink();
    return GlassCard(
      tint: BlockColors.danger,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: BlockColors.danger),
        title: const Text('Faltan permisos'),
        subtitle: const Text('Sin ellos Block no puede bloquear el móvil.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SetupScreen())),
      ),
    );
  }
}
