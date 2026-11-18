import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/session/application/session_controller.dart';
import 'shared/blocker/blocker.dart';
import 'shared/config.dart';
import 'shared/desktop/local_bridge.dart';
import 'shared/desktop/windows_shell.dart';
import 'shared/providers.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.cloudEnabled) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
  }
  final blocker = Blocker(onRoute: openRoute);
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
      blockerProvider.overrideWithValue(blocker),
    ],
  );
  // La sesion se hace cumplir aunque la ventana este oculta en la bandeja.
  container.listen(sessionControllerProvider, (_, _) {});

  if (Platform.isWindows) {
    await WindowsShell(container).init(startHidden: args.contains('--minimized'));
    await blocker.setAutostart(true);
    await LocalBridge(container).start();
  }

  runApp(UncontrolledProviderScope(container: container, child: const BlockApp()));

  if (Platform.isAndroid) {
    final route = await blocker.initialRoute();
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openRoute(route));
    }
  }
}
