package com.Fernando_S_ac.gym_tracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.fitness.FitnessLocal
import com.google.android.gms.fitness.LocalRecordingClient
import com.google.android.gms.fitness.data.LocalDataType
import com.google.android.gms.fitness.request.LocalDataReadRequest
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.time.ZonedDateTime
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

class MainActivity : AudioServiceActivity(), SensorEventListener {
    private val channelName = "stk_haven/daily_steps"
    private var restTonePlayer: MediaPlayer? = null
    private val legacyPermissionRequest = 7412
    private val accessPermissionRequest = 7413

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingAccessResult: MethodChannel.Result? = null
    private var pendingStepsResult: MethodChannel.Result? = null
    private var pendingStepsWrapAccess = false
    private var recordingSubscriptionReady = false
    private lateinit var sensorManager: SensorManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Disabled-by-default experimental native GPU rasterizer for static
        // anatomical GLB review. Never instantiated by workout screens.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "stk_haven/anatomy_gpu_static",
            StkAnatomyGpuReviewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        // Separate GLES3 shader-skinned pilot, never selected in production.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "stk_haven/anatomy_gpu_skinning",
            StkAnatomyGpuSkinnedFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stk_haven/private_journal")
            .setMethodCallHandler { call, result ->
                if (call.method == "authenticate") {
                    if (Build.VERSION.SDK_INT < 30) {
                        result.success(false)
                    } else {
                        val manager = getSystemService(android.hardware.biometrics.BiometricManager::class.java)
                        val authenticators = android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        if (manager?.canAuthenticate(authenticators) != android.hardware.biometrics.BiometricManager.BIOMETRIC_SUCCESS) {
                            result.success(false)
                        } else {
                            val prompt = android.hardware.biometrics.BiometricPrompt.Builder(this)
                                .setTitle("Abrir diario privado").setAllowedAuthenticators(authenticators).build()
                            prompt.authenticate(android.os.CancellationSignal(), mainExecutor,
                                object : android.hardware.biometrics.BiometricPrompt.AuthenticationCallback() {
                                    override fun onAuthenticationSucceeded(value: android.hardware.biometrics.BiometricPrompt.AuthenticationResult) {
                                        result.success(true)
                                    }
                                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                        result.success(false)
                                    }
                                })
                        }
                    }
                    return@setMethodCallHandler
                }
                try {
                    val file = android.util.AtomicFile(java.io.File(noBackupFilesDir, "stk_private_journal.bin"))
                    val alias = "stk_private_journal_key_v1"
                    val store = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                    fun key(): javax.crypto.SecretKey {
                        val existing = store.getKey(alias, null) as? javax.crypto.SecretKey
                        if (existing != null) return existing
                        val generator = javax.crypto.KeyGenerator.getInstance("AES", "AndroidKeyStore")
                        generator.init(android.security.keystore.KeyGenParameterSpec.Builder(alias,
                            android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or android.security.keystore.KeyProperties.PURPOSE_DECRYPT)
                            .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                            .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                            .setKeySize(256).build())
                        return generator.generateKey()
                    }
                    when (call.method) {
                        "read" -> {
                            if (!file.baseFile.exists()) result.success("[]")
                            else {
                                val bytes = file.readFully()
                                require(bytes.size > 12)
                                val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
                                cipher.init(javax.crypto.Cipher.DECRYPT_MODE, key(), javax.crypto.spec.GCMParameterSpec(128, bytes.copyOfRange(0,12)))
                                result.success(String(cipher.doFinal(bytes.copyOfRange(12,bytes.size)), Charsets.UTF_8))
                            }
                        }
                        "write" -> {
                            val data = call.argument<String>("data") ?: throw IllegalArgumentException()
                            val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, key())
                            require(cipher.iv.size == 12)
                            val bytes = cipher.iv + cipher.doFinal(data.toByteArray(Charsets.UTF_8))
                            val stream = file.startWrite()
                            try { stream.write(bytes); file.finishWrite(stream) }
                            catch (e: Exception) { file.failWrite(stream); throw e }
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("journal_storage", "No se pudo acceder al diario privado", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stk_haven/pdf_reader")
            .setMethodCallHandler { call, result ->
                if (call.method == "searchText") {
                    val path = call.argument<String>("path")
                    val query = call.argument<String>("query").orEmpty().take(200)
                    if (android.os.Build.VERSION.SDK_INT < 35 || path == null) {
                        result.error("pdf_search_unavailable", "Búsqueda no disponible", null)
                    } else Thread {
                        try {
                            val file = java.io.File(path).canonicalFile
                            val root = java.io.File(filesDir.parentFile, "app_flutter").canonicalFile
                            require(file.path.startsWith(root.path + java.io.File.separator))
                            val fd = android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY)
                            val renderer = try { android.graphics.pdf.PdfRenderer(fd) } catch (e: Exception) { fd.close(); throw e }
                            val matches = mutableListOf<Int>()
                            renderer.use { pdf ->
                                for (i in 0 until pdf.pageCount) {
                                    pdf.openPage(i).use { page ->
                                        val search = page.javaClass.getMethod("searchText", String::class.java)
                                        val found = search.invoke(page, query) as? List<*>
                                        if (!found.isNullOrEmpty()) matches.add(i + 1)
                                    }
                                    if (matches.size >= 200) break
                                }
                            }
                            runOnUiThread { result.success(matches) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("pdf_search_unavailable", "Búsqueda no disponible", null) }
                        }
                    }.start()
                } else if (call.method != "renderPage") {
                    result.notImplemented()
                } else {
                    val path = call.argument<String>("path")
                    val requested = call.argument<Int>("page") ?: 1
                    val thumbnail = call.argument<Boolean>("thumbnail") == true
                    val highlightTerms = call.argument<List<String>>("highlightTerms").orEmpty().take(20)
                    if (path == null) {
                        result.error("pdf_missing", "PDF no disponible", null)
                    } else {
                        Thread {
                            try {
                                val file = java.io.File(path).canonicalFile
                                val root = java.io.File(filesDir.parentFile, "app_flutter").canonicalFile
                                require(file.path.startsWith(root.path + java.io.File.separator))
                                val fd = android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY)
                                val renderer = try { android.graphics.pdf.PdfRenderer(fd) } catch (e: Exception) { fd.close(); throw e }
                                renderer.use { pdf ->
                                    require(pdf.pageCount > 0)
                                    val index = (requested - 1).coerceIn(0, pdf.pageCount - 1)
                                    pdf.openPage(index).use { page ->
                                        val scale = if (thumbnail) minOf(220f / page.width, 300f / page.height) else minOf(1600f / page.width, 2200f / page.height)
                                        val bitmap = android.graphics.Bitmap.createBitmap(
                                            (page.width * scale).toInt().coerceAtLeast(1),
                                            (page.height * scale).toInt().coerceAtLeast(1),
                                            android.graphics.Bitmap.Config.ARGB_8888)
                                        try {
                                            bitmap.eraseColor(android.graphics.Color.WHITE)
                                            page.render(bitmap, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                            if (Build.VERSION.SDK_INT >= 35 && highlightTerms.isNotEmpty()) {
                                                val canvas = android.graphics.Canvas(bitmap)
                                                val paint = android.graphics.Paint().apply { color = 0x55FFFF00 }
                                                for (term in highlightTerms) {
                                                    try {
                                                        val matches = page.javaClass.getMethod("searchText", String::class.java).invoke(page, term.take(200)) as? List<*>
                                                        for (match in matches.orEmpty()) {
                                                            if (match == null) continue
                                                            val bounds = match.javaClass.getMethod("getBounds").invoke(match) as? List<*>
                                                            for (rect in bounds.orEmpty()) {
                                                                if (rect is android.graphics.RectF) canvas.drawRect(rect.left * scale, rect.top * scale, rect.right * scale, rect.bottom * scale, paint)
                                                            }
                                                        }
                                                    } catch (_: Exception) { /* text extraction unavailable on this page */ }
                                                }
                                            }
                                            val stream = java.io.ByteArrayOutputStream()
                                            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                                            val payload = mapOf("bytes" to stream.toByteArray(), "currentPage" to index + 1, "totalPages" to pdf.pageCount)
                                            runOnUiThread { result.success(payload) }
                                        } finally { bitmap.recycle() }
                                    }
                                }
                            } catch (_: Exception) {
                                runOnUiThread { result.error("pdf_unreadable", "No se pudo abrir el PDF", null) }
                            }
                        }.start()
                    }
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stk_haven/timezone",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTimeZoneName" -> result.success(TimeZone.getDefault().id)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stk_haven/verse_widget",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    val args = call.arguments as? Map<*, *>
                    val text = (args?.get("text") as? String)?.trim().orEmpty()
                    val reference = (args?.get("reference") as? String)?.trim().orEmpty()
                    val date = (args?.get("date") as? String).orEmpty()
                    if (text.isEmpty() || reference.isEmpty()) {
                        result.error("invalid_verse", "A verse and reference are required.", null)
                    } else {
                        getSharedPreferences("stk_verse_widget", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("enabled", true)
                            .putString("text", text.take(1200))
                            .putString("reference", reference.take(120))
                            .putString("date", date)
                            .apply()
                        VerseWidgetProvider.refreshAll(this)
                        result.success(true)
                    }
                }
                "clear" -> {
                    getSharedPreferences("stk_verse_widget", Context.MODE_PRIVATE)
                        .edit().putBoolean("enabled", false)
                        .remove("text").remove("reference").remove("date")
                        .apply()
                    VerseWidgetProvider.refreshAll(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stk_haven/rest_expiry",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val deadline = call.argument<Number>("endEpochMillis")?.toLong()
                    if (deadline == null) {
                        result.success(false)
                    } else {
                        result.success(
                            StkRestCountdownExpiryReceiver.schedule(this, deadline)
                        )
                    }
                }
                "cancel" -> {
                    StkRestCountdownExpiryReceiver.cancel(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stk_haven/rest_tone",
        ).setMethodCallHandler { call, result ->
            if (call.method != "play") {
                result.notImplemented()
            } else {
                try {
                    restTonePlayer?.release()
                    restTonePlayer = null

                    // A one-second training chime is SONIFICATION, not
                    // media playback. Never request or steal audio focus
                    // from YouTube Music, Spotify or another media app.
                    val player = MediaPlayer()
                    try {
                        player.setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build(),
                        )
                        val descriptor = resources.openRawResourceFd(
                            R.raw.stk_rest_complete,
                        )
                        try {
                            player.setDataSource(
                                descriptor.fileDescriptor,
                                descriptor.startOffset,
                                descriptor.length,
                            )
                        } finally {
                            descriptor.close()
                        }
                        player.prepare()
                        player.setOnCompletionListener { completed ->
                            completed.release()
                            if (restTonePlayer === completed) restTonePlayer = null
                        }
                        player.setOnErrorListener { failed, _, _ ->
                            failed.release()
                            if (restTonePlayer === failed) restTonePlayer = null
                            true
                        }
                        restTonePlayer = player
                        player.start()
                        result.success(true)
                    } catch (_: Exception) {
                        player.release()
                        restTonePlayer = null
                        result.success(false)
                    }
                } catch (_: Exception) {
                    restTonePlayer = null
                    result.success(false)
                }
            }
        }

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

        // Prefer Google's accountless local Recording API. Its subscription
        // continues collecting step deltas while STK Haven is not running and
        // survives system restarts. If Play services is unavailable, fall back
        // to the hardware TYPE_STEP_COUNTER implementation below.
        if (tryReadTodayStepsFromRecordingApi(result, wrapAccess)) {
            return
        }

        readTodayStepsFromSensor(result, wrapAccess)
    }

    private fun tryReadTodayStepsFromRecordingApi(
        result: MethodChannel.Result,
        wrapAccess: Boolean,
    ): Boolean {
        val playServicesStatus = GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(
                this,
                LocalRecordingClient.LOCAL_RECORDING_CLIENT_MIN_VERSION_CODE,
            )
        if (playServicesStatus != ConnectionResult.SUCCESS) {
            return false
        }

        return try {
            val client = FitnessLocal.getLocalRecordingClient(this)
            if (recordingSubscriptionReady) {
                readRecordedTodaySteps(client, result, wrapAccess)
            } else {
                client.subscribe(LocalDataType.TYPE_STEP_COUNT_DELTA)
                    .addOnSuccessListener {
                        recordingSubscriptionReady = true
                        readRecordedTodaySteps(client, result, wrapAccess)
                    }
                    .addOnFailureListener {
                        readTodayStepsFromSensor(result, wrapAccess)
                    }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readRecordedTodaySteps(
        client: LocalRecordingClient,
        result: MethodChannel.Result,
        wrapAccess: Boolean,
    ) {
        val end = ZonedDateTime.now()
        val start = end.toLocalDate().atStartOfDay(end.zone)
        val request = LocalDataReadRequest.Builder()
            .setTimeRange(
                start.toInstant().toEpochMilli(),
                end.toInstant().toEpochMilli(),
                TimeUnit.MILLISECONDS,
            )
            .read(LocalDataType.TYPE_STEP_COUNT_DELTA)
            .build()

        client.readData(request)
            .addOnSuccessListener { response ->
                val dataSet = response.getDataSet(
                    LocalDataType.TYPE_STEP_COUNT_DELTA,
                )
                var total = 0
                for (point in dataSet.dataPoints) {
                    val field = point.dataType.fields.firstOrNull() ?: continue
                    val value = try {
                        point.getValue(field).asInt()
                    } catch (_: IllegalStateException) {
                        0
                    }
                    total += value.coerceAtLeast(0)
                }
                deliverSteps(
                    result,
                    total.coerceIn(0, 250000),
                    wrapAccess,
                )
            }
            .addOnFailureListener {
                readTodayStepsFromSensor(result, wrapAccess)
            }
    }

    private fun readTodayStepsFromSensor(
        result: MethodChannel.Result,
        wrapAccess: Boolean,
    ) {
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

    private fun deliverSteps(
        result: MethodChannel.Result,
        steps: Int,
        wrapAccess: Boolean,
    ) {
        if (wrapAccess) {
            result.success(
                mapOf(
                    "status" to "authorized",
                    "steps" to steps,
                ),
            )
        } else {
            result.success(steps)
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
        deliverSteps(result, todaySteps, wrapAccess)
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
