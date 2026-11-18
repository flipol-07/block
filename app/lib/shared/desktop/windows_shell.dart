import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/session/application/session_controller.dart';

/// Ventana + icono en la bandeja. Cerrar la ventana la oculta: Block sigue
/// vigilando. Durante una sesion tampoco se puede salir desde la bandeja.
class WindowsShell with TrayListener, WindowListener {
  WindowsShell(this._container);

  final ProviderContainer _container;

  bool get _sessionActive => _container.read(sessionControllerProvider).session != null;

  Future<void> init({required bool startHidden}) async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(460, 780),
      minimumSize: Size(400, 600),
      center: true,
      title: 'Block',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (!startHidden) await show();
    });
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await trayManager.setIcon('assets/tray.ico');
    await trayManager.setToolTip('Block');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: 'Abrir Block'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Salir'),
    ]));
    trayManager.addListener(this);
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() => windowManager.hide();

  @override
  void onTrayIconMouseDown() => show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        show();
      case 'quit':
        if (_sessionActive) {
          show(); // No se sale a mitad de sesion: para eso esta la salida de emergencia.
        } else {
          trayManager.destroy();
          windowManager.destroy();
        }
    }
  }
}
