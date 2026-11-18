package com.plore.block

import android.annotation.SuppressLint
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import com.plore.block.blocker.BlockAccessibilityService
import com.plore.block.blocker.BlockDeviceAdmin
import com.plore.block.blocker.LockStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var pendingRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingRoute = intent?.getStringExtra(EXTRA_ROUTE)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "block/blocker")
        channel.setMethodCallHandler { call, result ->
            try {
                result.success(handle(call))
            } catch (e: Exception) {
                result.error("blocker", e.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(EXTRA_ROUTE)?.let { channel.invokeMethod("route", it) }
    }

    private fun handle(call: MethodCall): Any? = when (call.method) {
        "applySession" -> {
            LockStore.apply(
                this,
                call.argument<String>("sessionId")!!,
                call.argument<Number>("endsAtServerMs")!!.toLong(),
                call.argument<Number>("serverNowMs")!!.toLong(),
            )
            BlockAccessibilityService.refresh()
            null
        }
        "clearSession" -> {
            clearSession()
            null
        }
        "permissions" -> mapOf(
            "accessibility" to BlockAccessibilityService.isEnabled(this),
            "deviceAdmin" to devicePolicy().isAdminActive(adminComponent()),
            "batteryUnrestricted" to (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .isIgnoringBatteryOptimizations(packageName),
        )
        "openAccessibilitySettings" -> open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        "requestDeviceAdmin" -> open(
            Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
                .putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Impide desinstalar Block durante una sesión de estudio.",
                ),
        )
        "requestBatteryExemption" -> requestBatteryExemption()
        "openAppDetails" -> open(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
        )
        "configureSync" -> {
            LockStore.saveSync(
                this,
                LockStore.SyncConfig(
                    url = call.argument("url")!!,
                    key = call.argument("key")!!,
                    deviceId = call.argument("deviceId")!!,
                    secret = call.argument("secret")!!,
                ),
            )
            BlockAccessibilityService.pollNow(this)
            null
        }
        "clearSync" -> {
            LockStore.clearSync(this)
            null
        }
        "initialRoute" -> pendingRoute.also { pendingRoute = null }
        else -> throw IllegalArgumentException("unknown method ${call.method}")
    }

    /**
     * Flutter pide desbloquear. Una sesion local se quita sin mas; una de la
     * nube solo la quita el servidor: se le pregunta y, si confirma que ya no
     * hay sesion, el sondeo la limpia. Asi un arranque de Flutter sin sesion
     * iniciada no puede desbloquear el movil.
     */
    private fun clearSession() {
        val lock = LockStore.get(this) ?: return
        if (lock.isLocal || LockStore.sync(this) == null) {
            LockStore.clear(this)
            BlockAccessibilityService.refresh()
        } else {
            BlockAccessibilityService.pollNow(this)
        }
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryExemption(): Any? = open(
        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")),
    )

    private fun open(intent: Intent): Any? {
        startActivity(intent)
        return null
    }

    private fun devicePolicy() =
        getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun adminComponent() = ComponentName(this, BlockDeviceAdmin::class.java)

    companion object {
        const val EXTRA_ROUTE = "route"
    }
}
