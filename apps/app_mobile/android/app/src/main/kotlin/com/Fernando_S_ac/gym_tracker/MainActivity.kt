package com.Fernando_S_ac.gym_tracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "stk_haven/daily_steps"
    private val legacyPermissionRequest = 7412
    private val accessPermissionRequest = 7413

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingAccessResult: MethodChannel.Result? = null
    private var pendingStepsResult: MethodChannel.Result? = null
    private var pendingStepsWrapAccess = false
    private lateinit var sensorManager: SensorManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAccess" -> requestActivityRecognitionAccess(result)
                "requestPermission" -> requestActivityRecognition(result)
                "getTodaySteps" -> readTodaySteps(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasActivityRecognitionPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasStepCounterSensor(): Boolean {
        return sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null
    }

    private fun requestActivityRecognitionAccess(result: MethodChannel.Result) {
        if (!hasStepCounterSensor()) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to "Step counter sensor is unavailable.",
                ),
            )
            return
        }

        if (hasActivityRecognitionPermission()) {
            readTodaySteps(result, wrapAccess = true)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            readTodaySteps(result, wrapAccess = true)
            return
        }

        pendingAccessResult?.success(mapOf("status" to "query_failed"))
        pendingAccessResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            accessPermissionRequest,
        )
    }

    private fun requestActivityRecognition(result: MethodChannel.Result) {
        if (hasActivityRecognitionPermission()) {
            result.success(true)
            return
        }

        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            legacyPermissionRequest,
        )
    }

    private fun readTodaySteps(
        result: MethodChannel.Result,
        wrapAccess: Boolean = false,
    ) {
        if (!hasActivityRecognitionPermission()) {
            if (wrapAccess) {
                result.success(mapOf("status" to "denied"))
            } else {
                result.error(
                    "permission_denied",
                    "Activity recognition permission is required.",
                    null,
                )
            }
            return
        }

        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            if (wrapAccess) {
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "message" to "Step counter sensor is unavailable.",
                    ),
                )
            } else {
                result.error(
                    "sensor_unavailable",
                    "Step counter sensor is unavailable.",
                    null,
                )
            }
            return
        }

        pendingStepsResult?.error(
            "superseded",
            "A newer step read replaced this request.",
            null,
        )
        pendingStepsResult = result
        pendingStepsWrapAccess = wrapAccess

        val registered = sensorManager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
        if (!registered) {
            pendingStepsResult = null
            pendingStepsWrapAccess = false
            if (wrapAccess) {
                result.success(
                    mapOf(
                        "status" to "query_failed",
                        "message" to "Step counter could not be started.",
                    ),
                )
            } else {
                result.error(
                    "sensor_start_failed",
                    "Step counter could not be started.",
                    null,
                )
            }
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return

        val result = pendingStepsResult ?: return
        val wrapAccess = pendingStepsWrapAccess
        pendingStepsResult = null
        pendingStepsWrapAccess = false
        sensorManager.unregisterListener(this)

        val cumulative = event.values.firstOrNull()?.toInt() ?: 0
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val prefs = getSharedPreferences(
            "stk_haven_steps",
            Context.MODE_PRIVATE,
        )
        val baselineDate = prefs.getString("baseline_date", null)
        var baseline = prefs.getInt("baseline_value", cumulative)

        if (baselineDate != today || cumulative < baseline) {
            baseline = cumulative
            prefs.edit()
                .putString("baseline_date", today)
                .putInt("baseline_value", baseline)
                .apply()
        }

        val todaySteps = (cumulative - baseline).coerceAtLeast(0)
        if (wrapAccess) {
            result.success(
                mapOf(
                    "status" to "authorized",
                    "steps" to todaySteps,
                ),
            )
        } else {
            result.success(todaySteps)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        )

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        when (requestCode) {
            legacyPermissionRequest -> {
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
            }
            accessPermissionRequest -> {
                val result = pendingAccessResult
                pendingAccessResult = null
                if (result != null) {
                    if (granted) {
                        readTodaySteps(result, wrapAccess = true)
                    } else {
                        result.success(mapOf("status" to "denied"))
                    }
                }
            }
        }
    }

    override fun onPause() {
        if (::sensorManager.isInitialized) {
            sensorManager.unregisterListener(this)
        }
        pendingStepsResult?.error(
            "cancelled",
            "Step read cancelled.",
            null,
        )
        pendingStepsResult = null
        pendingStepsWrapAccess = false
        super.onPause()
    }
}
