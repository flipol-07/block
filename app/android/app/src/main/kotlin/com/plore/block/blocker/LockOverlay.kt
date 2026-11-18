package com.plore.block.blocker

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.plore.block.MainActivity

/**
 * Pantalla de "Block activo" que tapa el movil entero. Es una ventana
 * TYPE_ACCESSIBILITY_OVERLAY: queda encima de todo (Ajustes incluido) y no
 * necesita el permiso de "mostrar sobre otras apps".
 */
class LockOverlay(private val service: AccessibilityService) {
    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null
    private lateinit var countdown: TextView

    val isShowing get() = root != null

    fun show(remainingMs: Long) {
        if (root == null) {
            val view = build()
            wm.addView(view, params())
            root = view
        }
        countdown.text = format(remainingMs)
    }

    fun hide() {
        root?.let { runCatching { wm.removeView(it) } }
        root = null
    }

    private fun params() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.OPAQUE,
    ).apply {
        gravity = Gravity.CENTER
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), service.resources.displayMetrics,
    ).toInt()

    private fun text(value: String, sizeSp: Float, color: Int, bold: Boolean = false) =
        TextView(service).apply {
            text = value
            textSize = sizeSp
            setTextColor(color)
            gravity = Gravity.CENTER
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

    private fun glass(radiusDp: Int, alpha: Int = 0x16) = GradientDrawable().apply {
        cornerRadius = dp(radiusDp).toFloat()
        setColor(Color.argb(alpha, 255, 255, 255))
        setStroke(dp(1), Color.argb(0x22, 255, 255, 255))
    }

    private fun button(label: String, onTap: () -> Unit) =
        text(label, 16f, TEXT, bold = true).apply {
            background = glass(28)
            setPadding(dp(20), dp(18), dp(20), dp(18))
            isClickable = true
            setOnClickListener { onTap() }
        }

    /** Fondo casi negro con una luz ambar suave arriba y otra azul abajo. */
    private fun backdrop() = android.graphics.drawable.LayerDrawable(
        arrayOf(
            GradientDrawable().apply { setColor(BACKGROUND) },
            GradientDrawable().apply {
                gradientType = GradientDrawable.RADIAL_GRADIENT
                gradientRadius = service.resources.displayMetrics.widthPixels * 0.9f
                setGradientCenter(0.15f, 0.1f)
                colors = intArrayOf(Color.argb(0x40, 0xE9, 0xC4, 0x6A), Color.TRANSPARENT)
            },
            GradientDrawable().apply {
                gradientType = GradientDrawable.RADIAL_GRADIENT
                gradientRadius = service.resources.displayMetrics.widthPixels * 0.9f
                setGradientCenter(0.95f, 0.85f)
                colors = intArrayOf(Color.argb(0x2E, 0x5B, 0x8C, 0xFF), Color.TRANSPARENT)
            },
        ),
    )

    private fun build(): View {
        countdown = text("", 64f, TEXT).apply {
            typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
            fontFeatureSettings = "tnum"
            letterSpacing = -0.02f
        }
        val card = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = glass(36)
            setPadding(dp(24), dp(32), dp(24), dp(32))
            addView(countdown)
            addView(space(6))
            addView(text("BLOCK ACTIVO", 12f, ACCENT, bold = true).apply { letterSpacing = 0.2f })
        }
        return LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = backdrop()
            setPadding(dp(32), dp(48), dp(32), dp(48))
            // Consumir todos los toques: nada llega a la app de debajo.
            isClickable = true
            addView(text("Block", 22f, TEXT, bold = true).apply { letterSpacing = -0.02f })
            addView(space(28))
            addView(card, fullWidth())
            addView(space(20))
            addView(text("Estás estudiando.\nEl móvil se desbloquea solo al terminar.", 15f, MUTED))
            addView(space(56))
            addView(button("Llamada de emergencia") { dialEmergency() }, fullWidth())
            addView(space(12))
            addView(text("Salida de emergencia", 14f, MUTED).apply {
                setPadding(dp(16), dp(12), dp(16), dp(12))
                setOnClickListener { openEmergencyExit() }
            })
        }
    }

    private fun space(heightDp: Int) = View(service).apply {
        layoutParams = LinearLayout.LayoutParams(1, dp(heightDp))
    }

    private fun fullWidth() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    )

    private fun dialEmergency() {
        service.startActivity(
            Intent(Intent.ACTION_DIAL, Uri.parse("tel:112"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun openEmergencyExit() {
        service.startActivity(
            Intent(service, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_ROUTE, "emergency")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
    }

    private fun format(ms: Long): String {
        val total = (ms + 999) / 1000
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
    }

    companion object {
        private val BACKGROUND = Color.parseColor("#07080B")
                private val ACCENT = Color.parseColor("#E9C46A")
        private val TEXT = Color.parseColor("#F1EFEA")
        private val MUTED = Color.parseColor("#8B8F98")
    }
}
