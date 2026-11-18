package com.plore.block.blocker

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.OffsetDateTime
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Consulta la sesion activa en Supabase con las credenciales del dispositivo
 * (no con el token del usuario: ese lo rota Flutter y compartirlo romperia la
 * sesion). Se llama al encender la pantalla y cada pocos segundos mientras
 * esta encendida.
 */
object RemoteSync {
    private const val TAG = "BlockSync"
    private val executor = Executors.newSingleThreadExecutor()
    private val inFlight = AtomicBoolean(false)
    private val main = Handler(Looper.getMainLooper())

    fun poll(ctx: Context, onDone: () -> Unit = {}) {
        val config = LockStore.sync(ctx) ?: return
        if (!inFlight.compareAndSet(false, true)) return
        val app = ctx.applicationContext
        executor.execute {
            try {
                handle(app, request(config))
            } catch (e: Exception) {
                Log.w(TAG, "poll failed: ${e.message}")
            } finally {
                inFlight.set(false)
                main.post(onDone)
            }
        }
    }

    private fun request(config: LockStore.SyncConfig): JSONObject {
        val conn = URL("${config.url}/rest/v1/rpc/device_session_state")
            .openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 5000
            conn.readTimeout = 5000
            conn.doOutput = true
            conn.setRequestProperty("apikey", config.key)
            conn.setRequestProperty("Content-Type", "application/json")
            val body = JSONObject()
                .put("p_device", config.deviceId)
                .put("p_secret", config.secret)
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
            if (conn.responseCode != 200) {
                throw IllegalStateException("HTTP ${conn.responseCode}")
            }
            return JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
        } finally {
            conn.disconnect()
        }
    }

    private fun handle(ctx: Context, json: JSONObject) {
        val serverNow = parseTime(json.getString("server_now"))
        val session = json.optJSONObject("session")
        val current = LockStore.get(ctx)
        if (session != null) {
            LockStore.apply(ctx, session.getString("id"), parseTime(session.getString("ends_at")), serverNow)
        } else if (current != null && !current.isLocal) {
            // La sesion termino en otro dispositivo (salida de emergencia).
            LockStore.clear(ctx)
        }
    }

    private fun parseTime(value: String): Long =
        OffsetDateTime.parse(value).toInstant().toEpochMilli()
}
