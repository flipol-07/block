package com.plore.block.blocker

import android.content.Context
import android.os.SystemClock
import android.provider.Settings

/**
 * Estado persistente del bloqueo y credenciales de sincronizacion.
 *
 * La hora de fin es del servidor. Para no depender del reloj del movil, al
 * aplicar una sesion se ancla la hora del servidor a `elapsedRealtime` (que no
 * cambia aunque el usuario toque la hora). Tras un reinicio ese reloj vuelve a
 * cero, asi que hasta la siguiente consulta al servidor se usa el reloj de
 * pared corregido con el ultimo desfase conocido.
 */
object LockStore {
    private const val PREFS = "block_lock"
    const val LOCAL_PREFIX = "local-"

    data class Lock(
        val sessionId: String,
        val endsAtServerMs: Long,
        val anchorServerMs: Long,
        val anchorElapsedMs: Long,
        val anchorBoot: Int,
        val offsetWallMs: Long,
    ) {
        val isLocal get() = sessionId.startsWith(LOCAL_PREFIX)
    }

    data class SyncConfig(val url: String, val key: String, val deviceId: String, val secret: String)

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun bootCount(ctx: Context) =
        Settings.Global.getInt(ctx.contentResolver, Settings.Global.BOOT_COUNT, 0)

    fun apply(ctx: Context, sessionId: String, endsAtServerMs: Long, serverNowMs: Long) {
        prefs(ctx).edit()
            .putString("sessionId", sessionId)
            .putLong("endsAt", endsAtServerMs)
            .putLong("anchorServer", serverNowMs)
            .putLong("anchorElapsed", SystemClock.elapsedRealtime())
            .putInt("anchorBoot", bootCount(ctx))
            .putLong("offsetWall", serverNowMs - System.currentTimeMillis())
            .apply()
    }

    fun get(ctx: Context): Lock? {
        val p = prefs(ctx)
        val id = p.getString("sessionId", null) ?: return null
        return Lock(
            sessionId = id,
            endsAtServerMs = p.getLong("endsAt", 0),
            anchorServerMs = p.getLong("anchorServer", 0),
            anchorElapsedMs = p.getLong("anchorElapsed", 0),
            anchorBoot = p.getInt("anchorBoot", -1),
            offsetWallMs = p.getLong("offsetWall", 0),
        )
    }

    fun clear(ctx: Context) {
        prefs(ctx).edit()
            .remove("sessionId").remove("endsAt").remove("anchorServer")
            .remove("anchorElapsed").remove("anchorBoot").remove("offsetWall")
            .apply()
    }

    private fun serverNow(ctx: Context, lock: Lock): Long =
        if (bootCount(ctx) == lock.anchorBoot) {
            lock.anchorServerMs + (SystemClock.elapsedRealtime() - lock.anchorElapsedMs)
        } else {
            System.currentTimeMillis() + lock.offsetWallMs
        }

    /** Milisegundos que quedan de bloqueo (0 si no hay). Limpia si ya acabo. */
    fun remainingMs(ctx: Context): Long {
        val lock = get(ctx) ?: return 0
        val remaining = lock.endsAtServerMs - serverNow(ctx, lock)
        if (remaining <= 0) clear(ctx)
        return remaining.coerceAtLeast(0)
    }

    // ------------------------------------------------------------ sync

    fun saveSync(ctx: Context, config: SyncConfig) {
        prefs(ctx).edit()
            .putString("syncUrl", config.url)
            .putString("syncKey", config.key)
            .putString("syncDevice", config.deviceId)
            .putString("syncSecret", config.secret)
            .apply()
    }

    fun sync(ctx: Context): SyncConfig? {
        val p = prefs(ctx)
        return SyncConfig(
            url = p.getString("syncUrl", null) ?: return null,
            key = p.getString("syncKey", null) ?: return null,
            deviceId = p.getString("syncDevice", null) ?: return null,
            secret = p.getString("syncSecret", null) ?: return null,
        )
    }

    fun clearSync(ctx: Context) {
        prefs(ctx).edit()
            .remove("syncUrl").remove("syncKey").remove("syncDevice").remove("syncSecret")
            .apply()
    }
}
