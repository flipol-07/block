import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_screen.dart';
import 'features/session/presentation/emergency_exit_screen.dart';
import 'features/session/presentation/home_screen.dart';
import 'shared/providers.dart';
import 'shared/ui/navigation.dart';
import 'shared/ui/theme.dart';
import 'shared/ui/glass.dart';

class BlockApp extends StatelessWidget {
  const BlockApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Block',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Gate(),
      );
}

/// Abre una ruta pedida desde fuera de Flutter (la pantalla de bloqueo nativa).
void openRoute(String route) {
  if (route != 'emergency') return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const EmergencyExitScreen()),
  );
}

/// Modo local -> inicio. Modo nube -> login y registro del dispositivo.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(localModeProvider)) return const HomeScreen();
    final user = ref.watch(currentUserProvider);
    if (user.isLoading && !user.hasValue) return const _Loading();
    if (user.value == null) return const AuthScreen();
    final device = ref.watch(deviceIdentityProvider);
    if (device.hasError) {
      return GlassScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No se pudo registrar este dispositivo:\n${device.error}',
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(deviceIdentityProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const GlassScaffold(body: Center(child: CircularProgressIndicator()));
}
