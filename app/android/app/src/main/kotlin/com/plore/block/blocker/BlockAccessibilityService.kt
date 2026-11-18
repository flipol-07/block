package com.plore.block.blocker

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityEvent

/**
 * Corazon del bloqueo en Android. Mientras haya una sesion activa muestra la
 * pantalla de Block encima de cualquier app, salvo las permitidas: la propia
 * Block (para la salida de emergencia), el telefono y el teclado.
 *
 * El sistema lo vuelve a arrancar solo tras un reinicio, asi que el bloqueo
 * sobrevive aunque Flutter no este abierto.
 */
class BlockAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var overlay: LockOverlay
    private var foregroundPkg: String? = null
    private var polling = false

    // Solo con la pantalla encendida: con ella apagada no hay nada que pintar.
    private val tick = object : Runnable {
        override fun run() {
            evaluate()
            if (isInteractive()) handler.postDelayed(this, 1000)
        }
    }

    private val poll = object : Runnable {
        override fun run() {
            RemoteSync.poll(this@BlockAccessibilityService) { evaluate() }
            // Sin sesion se consulta a menudo para bloquear rapido; con sesion,
            // menos, solo para enterarse de una salida de emergencia en el PC.
            val delay = if (LockStore.get(this@BlockAccessibilityService) == null) 2000L else 10000L
            if (polling) handler.postDelayed(this, delay)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                    startPolling()
                    handler.removeCallbacks(tick)
                    handler.post(tick)
                }
                Intent.ACTION_SCREEN_OFF -> {
                    stopPolling()
                    handler.removeCallbacks(tick)
                }
            }
        }
    }

    override fun onServiceConnected() {
        instance = this
        overlay = LockOverlay(this)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
        if (isInteractive()) startPolling()
        handler.post(tick)
    }

    private fun isInteractive() =
        (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive

    private fun isKeyguardLocked() =
        (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        // El paquete del evento basta casi siempre. Solo si el evento viene de
        // Block (puede ser nuestra propia capa) se pregunta cual es la ventana
        // activa: esa llamada cruza procesos y puede bloquear el hilo.
        var pkg = event.packageName?.toString()
        if (pkg == packageName) {
            pkg = runCatching { rootInActiveWindow?.packageName?.toString() }.getOrNull()
        }
        if (pkg != null) foregroundPkg = pkg
        // Cerrar el panel de notificaciones, pero nunca con la pantalla apagada o
        // en la pantalla de bloqueo: ahi systemui es el keyguard y cerrarlo
        // volvia a encender la pantalla.
        if (pkg == "com.android.systemui" && LockStore.get(this) != null &&
            isInteractive() && !isKeyguardLocked() &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        ) {
            performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
        }
        evaluate()
    }

    fun evaluate() {
        if (!::overlay.isInitialized) return
        val remaining = LockStore.remainingMs(this)
        if (remaining > 0 && !isAllowed(foregroundPkg)) overlay.show(remaining) else overlay.hide()
    }

    private fun isAllowed(pkg: String?): Boolean {
        if (pkg == null) return false
        if (pkg == packageName) return true
        return pkg in allowedPackages()
    }

    private fun allowedPackages(): Set<String> {
        val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val ime = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.let { ComponentName.unflattenFromString(it)?.packageName }
        return setOfNotNull(
            telecom.defaultDialerPackage,
            ime,
            "com.android.server.telecom",
            "com.android.phone",
            "com.android.incallui",
            "com.google.android.dialer",
            "com.samsung.android.incallui",
            "com.android.emergency",
        )
    }

    private fun startPolling() {
        if (polling) return
        polling = true
        handler.post(poll)
    }

    private fun stopPolling() {
        polling = false
        handler.removeCallbacks(poll)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        instance = null
        stopPolling()
        handler.removeCallbacks(tick)
        runCatching { unregisterReceiver(screenReceiver) }
        if (::overlay.isInitialized) overlay.hide()
        super.onDestroy()
    }

    companion object {
        @Volatile
        var instance: BlockAccessibilityService? = null

        fun refresh() {
            instance?.let { s -> s.handler.post { s.evaluate() } }
        }

        fun pollNow(ctx: Context) {
            RemoteSync.poll(ctx) { refresh() }
        }

        fun isEnabled(ctx: Context): Boolean {
            val enabled = Settings.Secure.getString(
                ctx.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            val me = ComponentName(ctx, BlockAccessibilityService::class.java)
            return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
        }
    }
}
