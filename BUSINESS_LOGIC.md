# BUSINESS_LOGIC.md - Block

> Generado por SaaS Factory | Fecha: 2026-11-18

## 1. Problema

**Dolor:** cuando estudias en el portátil, el móvil y las apps de mensajería del propio PC (WhatsApp, Discord…) te sacan de la concentración una y otra vez. La fuerza de voluntad no basta: el móvil está a un brazo de distancia.

**Coste actual:** sesiones de estudio que rinden la mitad. Además, los bloqueadores que hay hoy fallan por cinco motivos (análisis de reseñas de 2026):

| # | Queja | % de reseñas negativas |
|---|---|---|
| 1 | Cobros sorpresa por suscripción | 24% |
| 2 | Demasiado fácil de saltar (desactivar Accesibilidad, desinstalar, cambiar la hora) | 19% |
| 3 | El móvil revoca los permisos solo (Xiaomi, Oppo…) | 16% |
| 4 | Mecánicas de culpa que salen mal (rachas perdidas, árbol que muere) | 12% |
| 5 | "Funcionó una semana y luego dejó de funcionar" | 10% |

Hay un problema más que casi ninguno resuelve: bloqueas un dispositivo y sigues distrayéndote con el otro.

## 2. Solución

**Propuesta de valor:** un bloqueador de concentración en el que el portátil manda. Empiezas una sesión en el PC y el móvil entero queda bloqueado hasta que termine. En el PC se bloquean apps y webs, y si quieres, todo menos una ventana.

**Flujo principal (happy path):**
1. En el PC eliges duración (25/50/90 min o personalizada) y, opcionalmente, "una sola ventana" (el PDF, VS Code…).
2. Block crea la sesión en el servidor, con una hora de fin fijada por el servidor.
3. El móvil la recibe en menos de 2 s si tiene la pantalla encendida, o al encenderla si estaba apagada. A partir de ahí solo se ve la pantalla de Block: cuenta atrás, llamada de emergencia (112) y salida de emergencia.
4. En el PC se cierran las apps de la lista, las webs bloqueadas redirigen a Block y, si elegiste ventana única, todo lo demás queda tapado.
5. Al llegar la hora, todo se desbloquea solo, aunque no haya conexión.
6. La salida de emergencia exige 60 s de espera, escribir una frase y dar un motivo. Termina la sesión en todos los dispositivos y queda en el historial.

## 3. Usuario objetivo

**Rol:** estudiante (primero el propio creador) con Windows y Android que quiere concentrarse y sabe que, si puede, mirará el móvil.

**Contexto:** uso personal primero, instalando el APK directamente. Después, posible producto de pago único.

## 4. Arquitectura de datos

**Input:**
- Duración de la sesión.
- Modo ventana única.
- Ventana elegida.
- Listas de apps y webs.
- Motivo de la salida de emergencia.

**Output:**
- Bloqueo en el móvil y en el PC.
- Historial: minutos por día, sesiones completadas y salidas de emergencia.

**Storage (Supabase, todas las tablas con RLS):**
- `devices`: dispositivos de la cuenta, cada uno con su propio secreto (guardado como hash).
- `focus_sessions`: sesiones. Se crean y cierran solo por RPC, para que las horas las fije el servidor.
- `block_rules`: apps y webs que se bloquean.
- Vista `focus_history`: estado efectivo y minutos de cada sesión.

## 5. KPI de éxito (MVP)

- Iniciar en el PC bloquea el móvil en menos de 2 s con la pantalla encendida.
- En el móvil, ni Ajustes, ni desinstalar la app, ni cambiar la hora rompen una sesión activa.
- El propio creador completa 5 sesiones reales sin usar la salida de emergencia ni conseguir saltárselo.

## 6. Especificación técnica

### Por qué no es Next.js
Block necesita bloquear el sistema operativo: un AccessibilityService en Android y hooks Win32 en Windows. Eso no se puede hacer desde la web. Por eso la app es **Flutter** (Android + Windows), con plugins nativos, y el backend sigue siendo **Supabase**, el del golden path.

```
app/
├── lib/
│   ├── features/
│   │   ├── auth/        # Login email/password (Supabase) + registro de dispositivo
│   │   ├── session/     # Modelo, reloj del servidor, controlador, salida de emergencia
│   │   ├── rules/       # Listas de apps/webs
│   │   └── history/     # Minutos, sesiones, salidas de emergencia
│   └── shared/
│       ├── blocker/     # Canal con el bloqueador nativo de cada plataforma
│       └── desktop/     # Bandeja de Windows + servidor local para la extensión
├── android/.../blocker/ # Kotlin: AccessibilityService, overlay, sync nativo, Device Admin
└── windows/runner/blocker/ # C++: guardia de procesos, overlay de ventana única, hook de teclado
extension/               # MV3 Chrome/Edge: redirige webs bloqueadas durante la sesión
supabase/migrations/
```

### Próximos pasos
1. [x] Proyecto base Flutter + esquema Supabase
2. [x] Bloqueo Android
3. [x] Bloqueo Windows
4. [x] Sincronización (backend probado de punta a punta)
5. [x] Extensión + historial
6. [ ] Probar en dispositivos reales (instalado en el A55 y en el PC; falta la prueba con sesión)
7. [ ] Endurecimiento: vigilante en Windows, FCM, aviso si se revoca la accesibilidad
