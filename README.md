# Block

Bloqueo de concentración para **Windows + Android** conectados. Empiezas una sesión en el PC y el móvil entero queda bloqueado hasta que acabe. En el PC se cierran las apps de tu lista, las webs bloqueadas redirigen a Block y, si quieres, todo queda tapado menos una ventana.

Contexto de negocio e investigación de mercado: [BUSINESS_LOGIC.md](BUSINESS_LOGIC.md).

## Cómo funciona

| Pieza | Dónde | Qué hace |
|---|---|---|
| App Flutter | `app/lib` | UI, sesiones, login, listas, historial (Android y Windows) |
| Bloqueo Android | `app/android/.../blocker` | AccessibilityService + pantalla `TYPE_ACCESSIBILITY_OVERLAY`, consulta la sesión al encender la pantalla y cada 2 s con pantalla encendida |
| Bloqueo Windows | `app/windows/runner/blocker` | Cierra procesos de la lista, modo una sola ventana (capa con agujero + foco + hook de teclado), arranque con Windows |
| Extensión | `extension/` | Redirige webs bloqueadas; lee `http://127.0.0.1:47613/state` de la app de Windows |
| Backend | `supabase/migrations` | Proyecto `block` (París). Sesiones con hora de fin fijada por el servidor, solo por RPC |

**El fin de sesión no depende de la red**: cada dispositivo guarda la hora de fin del servidor, anclada a un reloj monótono, y se desbloquea solo. Cambiar la hora del móvil no sirve para saltárselo.

**El móvil no usa el token del usuario**: el servicio nativo consulta con un secreto propio del dispositivo (`device_session_state`), así que funciona aunque Flutter esté cerrado.

## Compilar

Configuración de la nube en `app/config.json` (fuera de git):

```json
{ "SUPABASE_URL": "https://<ref>.supabase.co", "SUPABASE_KEY": "<publishable/anon key>" }
```

**Android** (desde WSL):

```bash
cd app && ~/flutter/bin/flutter build apk --release --dart-define-from-file=config.json
```

**Windows**: MSBuild no compila desde rutas `\\wsl.localhost`, así que se copia a `C:\src\block-build` y se compila con el Flutter de Windows:

```powershell
robocopy \\wsl.localhost\ubuntu\home\plore\proyectos\mio\Block\app C:\src\block-build /MIR /XD build .dart_tool android .idea ephemeral /R:0 /W:0
cd C:\src\block-build; C:\src\flutter\bin\flutter.bat build windows --release --dart-define-from-file=config.json
```

Hay que excluir `ephemeral`: dentro hay enlaces simbólicos de Linux que bloquean robocopy.

Instalación en este PC: `%LOCALAPPDATA%\Programs\Block\block.exe`. Arranca con Windows, oculto en la bandeja.

## Tests

```bash
cd app && ~/flutter/bin/flutter analyze && ~/flutter/bin/flutter test
```

## Límites conocidos

- **Android**: arrancar en modo seguro desactiva Block, y eso no se puede evitar. Android 17 con Protección Avanzada retira el permiso de accesibilidad.
- **Windows**: Ctrl+Alt+Supr y el Administrador de tareas siguen funcionando.
- Block pone **fricción, no seguridad absoluta**, igual que toda la competencia.
