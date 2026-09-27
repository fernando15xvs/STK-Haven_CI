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
    private val activityRecognitionRequest = 7412
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingStepsResult: MethodChannel.Result? = null
    private lateinit var sensorManager: SensorManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
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
            activityRecognitionRequest,
        )
    }

    private fun readTodaySteps(result: MethodChannel.Result) {
        if (!hasActivityRecognitionPermission()) {
            result.error(
                "permission_denied",
                "Activity recognition permission is required.",
                null,
            )
            return
        }

        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            result.error(
                "sensor_unavailable",
                "Step counter sensor is unavailable.",
                null,
            )
            return
        }

        pendingStepsResult?.error(
            "superseded",
            "A newer step read replaced this request.",
            null,
        )
        pendingStepsResult = result
        sensorManager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return

        val result = pendingStepsResult ?: return
        pendingStepsResult = null
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

        result.success((cumulative - baseline).coerceAtLeast(0))
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

        if (requestCode == activityRecognitionRequest) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onPause() {
        sensorManager.unregisterListener(this)
        pendingStepsResult?.error(
            "cancelled",
            "Step read cancelled.",
            null,
        )
        pendingStepsResult = null
        super.onPause()
    }
}
