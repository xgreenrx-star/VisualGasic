// ============================================================================
//  VGAndroidPlugin.kt
//  VisualGasic Godot Android plugin — bridges GPS / Steps / Permission signals
//  into the engine so VG-BASIC code can use them via the Pass-4 namespaces
//  (GPS.*, Steps.*, Permission.*) and the auto-wired global subs:
//
//      Sub Permission_Granted(name As String) ...
//      Sub Permission_Denied(name As String)  ...
//      Sub GPS_Updated(lat As Double, lng As Double, alt As Double,
//                      accuracy As Double, speed As Double)
//      Sub Steps_Detected(today As Integer, total As Integer)
//
//  Build with `./gradlew assembleRelease` — produces VGAndroidPlugin.aar.
//  Drop the .aar next to VGAndroidPlugin.gdap and the engine will load it on
//  Android builds.  On every other platform the VG runtime detects the
//  absence of the singleton and falls back to the safe zero stubs already
//  registered in src/visual_gasic_builtins.cpp.
// ============================================================================

package org.visualgasic.android

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class VGAndroidPlugin(godot: Godot) : GodotPlugin(godot) {

    // ─── Plugin identity ────────────────────────────────────────────────────
    override fun getPluginName(): String = "VGAndroidPlugin"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("permission_granted", String::class.java),
        SignalInfo("permission_denied",  String::class.java),
        // (lat, lng, alt, accuracy_m, speed_mps)
        SignalInfo("gps_updated",
            Double::class.java, Double::class.java, Double::class.java,
            Double::class.java, Double::class.java),
        // (today, total) — Android exposes a since-boot total; "today" is
        // derived from a midnight checkpoint we cache on first read.
        SignalInfo("steps_detected", Integer::class.java, Integer::class.java)
    )

    // ─── State ──────────────────────────────────────────────────────────────
    private val ctx: Context get() = activity ?: godot.requireContext()
    private val act: Activity? get() = activity

    // GPS
    private var locationManager: LocationManager? = null
    private var lastLocation: Location? = null
    private var gpsActive: Boolean = false

    // Steps
    private var sensorManager: SensorManager? = null
    private var stepCounter: Sensor? = null
    private var stepsActive: Boolean = false
    private var stepsBootBaseline: Int = -1     // counter value when we first read
    private var stepsTodayBaseline: Int = -1    // counter value at midnight
    private var stepsTotal: Int = 0             // last counter value seen
    private var stepsTodayCheckpointDay: Int = -1   // calendar day-of-year of midnight checkpoint

    // ─── Permissions ────────────────────────────────────────────────────────
    @UsedByGodot
    fun hasPermission(name: String): Boolean {
        val full = expandShort(name)
        return ContextCompat.checkSelfPermission(ctx, full) == PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun requestPermission(name: String) {
        val a = act ?: return
        val full = expandShort(name)
        if (hasPermission(name)) {
            emitSignal("permission_granted", full)
            return
        }
        a.requestPermissions(arrayOf(full), PERMISSION_REQUEST_CODE)
        // Result is delivered to onMainRequestPermissionsResult below.
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        for (i in permissions.indices) {
            val granted = i < grantResults.size &&
                grantResults[i] == PackageManager.PERMISSION_GRANTED
            emitSignal(
                if (granted) "permission_granted" else "permission_denied",
                permissions[i]
            )
        }
    }

    private fun expandShort(name: String): String {
        if (name.startsWith("android.permission.")) return name
        return when (name.lowercase()) {
            "camera"                  -> Manifest.permission.CAMERA
            "microphone"              -> Manifest.permission.RECORD_AUDIO
            "location",
            "fine_location"           -> Manifest.permission.ACCESS_FINE_LOCATION
            "coarse_location"         -> Manifest.permission.ACCESS_COARSE_LOCATION
            "storage"                 -> Manifest.permission.READ_EXTERNAL_STORAGE
            "activity_recognition",
            "steps"                   -> Manifest.permission.ACTIVITY_RECOGNITION
            else -> name
        }
    }

    // ─── GPS ────────────────────────────────────────────────────────────────
    @UsedByGodot
    fun startGps(): Boolean {
        if (gpsActive) return true
        if (!hasPermission("location")) return false
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        locationManager = lm
        try {
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0.5f, gpsListener)
            // Some devices only have network provider — try that too.
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1000L, 0.5f, gpsListener)
            }
            gpsActive = true
            return true
        } catch (e: SecurityException) {
            return false
        }
    }

    @UsedByGodot
    fun stopGps() {
        locationManager?.removeUpdates(gpsListener)
        gpsActive = false
    }

    @UsedByGodot fun getLat():       Double = lastLocation?.latitude  ?: 0.0
    @UsedByGodot fun getLng():       Double = lastLocation?.longitude ?: 0.0
    @UsedByGodot fun getAlt():       Double = lastLocation?.altitude  ?: 0.0
    @UsedByGodot fun getSpeed():     Double = (lastLocation?.speed?.toDouble()) ?: 0.0
    @UsedByGodot fun getAccuracy():  Double = (lastLocation?.accuracy?.toDouble()) ?: -1.0

    private val gpsListener = object : LocationListener {
        override fun onLocationChanged(loc: Location) {
            lastLocation = loc
            emitSignal("gps_updated",
                loc.latitude, loc.longitude, loc.altitude,
                loc.accuracy.toDouble(), loc.speed.toDouble())
        }
        @Suppress("DEPRECATION")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    // ─── Steps ──────────────────────────────────────────────────────────────
    @UsedByGodot
    fun startSteps(): Boolean {
        if (stepsActive) return true
        if (!hasPermission("activity_recognition")) return false
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return false
        val s  = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return false
        sensorManager = sm
        stepCounter   = s
        sm.registerListener(stepListener, s, SensorManager.SENSOR_DELAY_NORMAL)
        stepsActive = true
        return true
    }

    @UsedByGodot
    fun stopSteps() {
        sensorManager?.unregisterListener(stepListener)
        stepsActive = false
    }

    @UsedByGodot
    fun resetSteps() {
        stepsBootBaseline  = stepsTotal
        stepsTodayBaseline = stepsTotal
    }

    @UsedByGodot fun getStepsTotal(): Int =
        if (stepsBootBaseline < 0) 0 else (stepsTotal - stepsBootBaseline)

    @UsedByGodot fun getStepsToday(): Int =
        if (stepsTodayBaseline < 0) 0 else (stepsTotal - stepsTodayBaseline)

    private val stepListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
            val raw = event.values[0].toInt()
            if (stepsBootBaseline < 0) stepsBootBaseline = raw
            // Roll the per-day baseline at midnight.
            val cal = java.util.Calendar.getInstance()
            val today = cal.get(java.util.Calendar.DAY_OF_YEAR)
            if (stepsTodayCheckpointDay != today) {
                stepsTodayCheckpointDay = today
                stepsTodayBaseline = raw
            }
            stepsTotal = raw
            emitSignal("steps_detected", getStepsToday(), getStepsTotal())
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    // ─── Lifecycle ──────────────────────────────────────────────────────────
    override fun onMainPause() { stopGps(); stopSteps() }
    override fun onMainDestroy() { stopGps(); stopSteps() }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 0x5645  // 'VE'
    }
}
