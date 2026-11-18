package com.plore.block.blocker

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Administrador de dispositivo sin politicas: su unico efecto es que Android
 * no deja desinstalar Block mientras este activo. Desactivarlo se hace en
 * Ajustes, que durante una sesion queda tapado por la pantalla de bloqueo.
 */
class BlockDeviceAdmin : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "Block ya no estará protegido contra la desinstalación."
}
