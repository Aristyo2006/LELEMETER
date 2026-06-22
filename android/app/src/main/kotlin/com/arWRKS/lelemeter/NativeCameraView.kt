package com.arWRKS.lelemeter

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.MeteringRectangle
import android.media.Image
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import android.view.TextureView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.Arrays
import kotlin.math.*

class NativeCameraView(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String?, Any?>?
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, TextureView.SurfaceTextureListener {

    private val textureView: TextureView = TextureView(context)
    private val appContext: Context = context
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.arWRKS.lelemeter/camera_methods_$id")
    private val eventChannel: EventChannel = EventChannel(messenger, "com.arWRKS.lelemeter/camera_events_$id")
    private var eventSink: EventChannel.EventSink? = null

    private val cameraManager: CameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var cameraId: String = ""
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var imageReader: ImageReader? = null

    // Camera States
    private var isAELocked = false
    private var zoomLevel = 1.0f
    private var bwMode = false
    private var evCompStops = 0
    private var meteringX = -1.0
    private var meteringY = -1.0
    private var lockedBaseEV = 8.0
    
    private var currentAvgY = 128.0
    private var currentIso = 100
    private var currentShutterNs = 20000000L

    // ── Still capture (logbook). Fully isolated from the preview/histogram path. ──
    private var stillImageReader: ImageReader? = null
    private var stillSession: CameraCaptureSession? = null
    private var captureResultCallback: MethodChannel.Result? = null
    private var captureFlashPosted = false
    private val captureLock = Any()
    
    // Cached buffers to prevent GC thrashing/pauses
    private var yBytes: ByteArray? = null
    private val rHist = IntArray(256)
    private val gHist = IntArray(256)
    private val bHist = IntArray(256)
    private var lastHistogramTime = 0L

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        textureView.surfaceTextureListener = this
    }

    override fun getView(): View = textureView

    override fun dispose() {
        closeCamera()
        stopBackgroundThread()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "lockAE" -> {
                isAELocked = true
                lockedBaseEV = call.argument<Double>("baseEV") ?: 8.0
                updatePreview()
                result.success(null)
            }
            "unlockAE" -> {
                isAELocked = false
                updatePreview()
                result.success(null)
            }
            "setMeteringPoint" -> {
                meteringX = call.argument<Double>("x") ?: -1.0
                meteringY = call.argument<Double>("y") ?: -1.0
                updatePreview()
                triggerAFOnce()
                result.success(null)
            }
            "setZoom" -> {
                zoomLevel = (call.argument<Double>("zoom") ?: 1.0).toFloat()
                updatePreview()
                result.success(null)
            }
            "setBlackAndWhite" -> {
                bwMode = call.argument<Boolean>("enabled") ?: false
                updatePreview()
                result.success(null)
            }
            "setEvComp" -> {
                evCompStops = call.argument<Int>("steps") ?: 0
                updatePreview()
                result.success(null)
            }
            "resumeCamera" -> {
                if (textureView.isAvailable) openCamera()
                result.success(null)
            }
            "capturePhoto" -> capturePhoto(result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onSurfaceTextureAvailable(st: SurfaceTexture, w: Int, h: Int) {
        openCamera()
    }
    override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) {}
    override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
        closeCamera()
        return true
    }
    override fun onSurfaceTextureUpdated(st: SurfaceTexture) {}

    @SuppressLint("MissingPermission")
    private fun openCamera() {
        startBackgroundThread()
        try {
            cameraId = cameraManager.cameraIdList.firstOrNull { 
                cameraManager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK 
            } ?: cameraManager.cameraIdList[0]
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCameraPreviewSession()
                }
                override fun onDisconnected(camera: CameraDevice) { closeCamera() }
                override fun onError(camera: CameraDevice, error: Int) { closeCamera() }
            }, backgroundHandler)
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun createCameraPreviewSession() {
        try {
            val texture = textureView.surfaceTexture ?: return
            texture.setDefaultBufferSize(640, 480)
            val surface = Surface(texture)

            imageReader = ImageReader.newInstance(320, 240, ImageFormat.YUV_420_888, 2)
            imageReader?.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                processHistogramAndExposure(image)
                image.close()
            }, backgroundHandler)

            cameraDevice?.createCaptureSession(Arrays.asList(surface, imageReader?.surface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    updatePreview()
                }
                override fun onConfigureFailed(session: CameraCaptureSession) {}
            }, null)
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun applyCommonSettings(builder: CaptureRequest.Builder) {
        builder.addTarget(Surface(textureView.surfaceTexture))
        imageReader?.surface?.let { builder.addTarget(it) }

        builder.set(CaptureRequest.CONTROL_AE_LOCK, isAELocked)
        builder.set(CaptureRequest.CONTROL_EFFECT_MODE, if (bwMode) CaptureRequest.CONTROL_EFFECT_MODE_MONO else CaptureRequest.CONTROL_EFFECT_MODE_OFF)
        builder.set(CaptureRequest.NOISE_REDUCTION_MODE, CaptureRequest.NOISE_REDUCTION_MODE_OFF)
        builder.set(CaptureRequest.EDGE_MODE, CaptureRequest.EDGE_MODE_OFF)
        
        val chars = cameraManager.getCameraCharacteristics(cameraId)
        
        // EV Comp
        val aeRange = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
        if (aeRange != null) builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, evCompStops.coerceIn(aeRange.lower, aeRange.upper))
        
        // --- PRO ZOOM LOGIC (iPhone-Style) ---
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val zoomRange = chars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
            if (zoomRange != null) {
                builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, zoomLevel.coerceIn(zoomRange.lower, zoomRange.upper))
            } else {
                applyCropZoom(builder, chars)
            }
        } else {
            applyCropZoom(builder, chars)
        }

        // --- METERING LOGIC ---
        val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
        if (sensorRect != null && meteringX >= 0.0) {
            val rect = calculateMeteringRect(chars, sensorRect)
            builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(rect))
            builder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(rect))
        }
    }

    private fun applyCropZoom(builder: CaptureRequest.Builder, chars: CameraCharacteristics) {
        val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
        if (sensorRect != null) {
            val cx = sensorRect.centerX(); val cy = sensorRect.centerY()
            val dx = (sensorRect.width() / (2f * zoomLevel)).toInt(); val dy = (sensorRect.height() / (2f * zoomLevel)).toInt()
            builder.set(CaptureRequest.SCALER_CROP_REGION, android.graphics.Rect(cx - dx, cy - dy, cx + dx, cy + dy))
        }
    }

    private fun updatePreview() {
        if (cameraDevice == null || captureSession == null) return
        try {
            val builder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            applyCommonSettings(builder)
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            captureSession?.setRepeatingRequest(builder.build(), object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                    currentIso = result.get(CaptureResult.SENSOR_SENSITIVITY) ?: 100
                    currentShutterNs = result.get(CaptureResult.SENSOR_EXPOSURE_TIME) ?: 20000000L
                }
            }, backgroundHandler)
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun triggerAFOnce() {
        if (cameraDevice == null || captureSession == null) return
        try {
            val builder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            applyCommonSettings(builder)
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
            builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_START)
            builder.set(CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER, CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER_START)
            captureSession?.capture(builder.build(), null, backgroundHandler)
        } catch (e: Exception) {}
    }

    // ───────────────────────────────────────────────────────────────────────────
    //  STILL CAPTURE (Logbook). Runs in a self-contained one-shot session that is
    //  fully independent from the live preview / histogram pipeline above.
    //  The existing `captureSession`, `imageReader`, EV/metering math are never
    //  touched here. After capture the live preview session is re-created.
    // ───────────────────────────────────────────────────────────────────────────
    @SuppressLint("MissingPermission")
    private fun capturePhoto(result: MethodChannel.Result) {
        synchronized(captureLock) {
            if (captureResultCallback != null) {
                // A capture is already in flight — reject the new request.
                result.error("busy", "A capture is already in progress", null)
                return
            }
            captureResultCallback = result
            captureFlashPosted = false
        }

        // Tear down the live preview session first so we can reconfigure with a JPEG surface.
        val device = cameraDevice
        if (device == null) {
            finishCapture(error = "camera_not_open")
            return
        }

        try {
            val chars = cameraManager.getCameraCharacteristics(cameraId)
            val jpegSizes = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?.getOutputSizes(ImageFormat.JPEG)
            // Keep still resolution reasonable to avoid huge memory spikes; prefer ~1080p-ish long edge.
            val target = jpegSizes?.maxByOrNull { it.width * it.height } ?: android.util.Size(1920, 1080)
            val maxLong = 1920
            val stillSize = if (maxOf(target.width, target.height) > maxLong) {
                val scale = maxLong.toDouble() / maxOf(target.width, target.height)
                android.util.Size(
                    (target.width * scale).toInt().coerceAtLeast(1),
                    (target.height * scale).toInt().coerceAtLeast(1),
                )
            } else target

            stillImageReader = ImageReader.newInstance(stillSize.width, stillSize.height, ImageFormat.JPEG, 2)
            stillImageReader?.setOnImageAvailableListener({ reader ->
                val image = reader.acquireNextImage() ?: return@setOnImageAvailableListener
                try {
                    val out = writeJpeg(image)
                    // Always restore preview, then resolve on the platform thread.
                    textureView.post { teardownStillAndResume() }
                    finishCapture(path = out)
                } catch (e: Exception) {
                    textureView.post { teardownStillAndResume() }
                    finishCapture(error = e.message ?: "write_failed")
                } finally {
                    image.close()
                }
            }, backgroundHandler)

            // Build a fresh session that includes ONLY the JPEG surface (still capture),
            // so the preview SurfaceTexture output is never re-aimed at still settings.
            device.createCaptureSession(
                listOfNotNull(stillImageReader?.surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        stillSession = session
                        runStillCapture(chars)
                    }
                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        textureView.post { teardownStillAndResume() }
                        finishCapture(error = "configure_failed")
                    }
                },
                backgroundHandler,
            )
        } catch (e: Exception) {
            textureView.post { teardownStillAndResume() }
            finishCapture(error = e.message ?: "capture_exception")
        }
    }

    private fun runStillCapture(chars: CameraCharacteristics) {
        try {
            val builder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            builder.addTarget(stillImageReader!!.surface)

            // Mirror the user's current capture intent (these are reads only — no state mutation).
            builder.set(CaptureRequest.CONTROL_AE_LOCK, isAELocked)
            builder.set(
                CaptureRequest.CONTROL_EFFECT_MODE,
                if (bwMode) CaptureRequest.CONTROL_EFFECT_MODE_MONO else CaptureRequest.CONTROL_EFFECT_MODE_OFF,
            )
            builder.set(CaptureRequest.JPEG_QUALITY, 92.toByte())

            // JPEG rotation from sensor orientation (portrait-friendly).
            val orientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            builder.set(CaptureRequest.JPEG_ORIENTATION, (orientation + 0) % 360)

            // Reuse the same zoom & EV-comp the preview shows.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val zoomRange = chars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                if (zoomRange != null) {
                    builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, zoomLevel.coerceIn(zoomRange.lower, zoomRange.upper))
                } else {
                    applyCropZoom(builder, chars)
                }
            } else {
                applyCropZoom(builder, chars)
            }
            val aeRange = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
            if (aeRange != null) {
                builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, evCompStops.coerceIn(aeRange.lower, aeRange.upper))
            }
            val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            if (sensorRect != null && meteringX >= 0.0) {
                val rect = calculateMeteringRect(chars, sensorRect)
                builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(rect))
                builder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(rect))
            }
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)

            stillSession?.capture(builder.build(), null, backgroundHandler)
        } catch (e: Exception) {
            textureView.post { teardownStillAndResume() }
            finishCapture(error = e.message ?: "still_capture_failed")
        }
    }

    private fun writeJpeg(image: Image): String {
        val buffer: ByteBuffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        val file = File(appContext.cacheDir, "capture_${System.currentTimeMillis()}.jpg")
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }

    /** Tear down the still session + reader, then rebuild the live preview session. */
    private fun teardownStillAndResume() {
        try {
            stillSession?.close()
        } catch (_: Exception) {}
        stillSession = null
        try {
            stillImageReader?.close()
        } catch (_: Exception) {}
        stillImageReader = null
        // Rebuild the original preview/analyzer session exactly as on open.
        createCameraPreviewSession()
    }

    /** Resolve the pending Flutter result exactly once. */
    private fun finishCapture(path: String? = null, error: String? = null) {
        val cb: MethodChannel.Result?
        synchronized(captureLock) {
            cb = captureResultCallback
            captureResultCallback = null
        }
        if (cb == null) return
        textureView.post {
            if (error != null) {
                cb!!.error(error, null, null)
            } else {
                cb!!.success(path)
            }
        }
    }

    private fun calculateMeteringRect(chars: CameraCharacteristics, sensorRect: android.graphics.Rect): MeteringRectangle {
        val orientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        var mappedX = meteringX; var mappedY = meteringY
        if (orientation == 90) { mappedX = meteringY; mappedY = 1.0 - meteringX }
        else if (orientation == 270) { mappedX = 1.0 - meteringY; mappedY = meteringX }
        
        val sensorX = (mappedX * sensorRect.width()).toInt() + sensorRect.left
        val sensorY = (mappedY * sensorRect.height()).toInt() + sensorRect.top
        val side = 150 
        return MeteringRectangle(
            max(sensorRect.left, min(sensorRect.right - side, sensorX - side / 2)),
            max(sensorRect.top, min(sensorRect.bottom - side, sensorY - side / 2)),
            side, side, 1000
        )
    }

    private var isProcessing = false
    private fun processHistogramAndExposure(image: android.media.Image) {
        if (isProcessing) return
        val now = System.currentTimeMillis()
        if (now - lastHistogramTime < 100) return // Throttle histogram to 10 FPS (100ms interval)
        isProcessing = true
        lastHistogramTime = now
        
        val yPlane = image.planes[0].buffer
        val remaining = yPlane.remaining()
        if (yBytes == null || yBytes!!.size != remaining) {
            yBytes = ByteArray(remaining)
        }
        yPlane.get(yBytes!!)
        
        rHist.fill(0)
        gHist.fill(0)
        bHist.fill(0)
        
        var totalY = 0L
        var maxV = 1
        val step = 2
        val bytes = yBytes!!
        for (i in 0 until remaining step step) {
            val y = bytes[i].toInt() and 0xFF
            totalY += y
            rHist[y]++
            gHist[y]++
            bHist[y]++
            if (rHist[y] > maxV) maxV = rHist[y]
        }
        currentAvgY = totalY.toDouble() / (remaining / step)
        
        val data = mapOf(
            "iso" to currentIso, 
            "shutterNs" to currentShutterNs, 
            "isLocked" to isAELocked,
            "calculatedEV" to lockedBaseEV, 
            "avgY" to currentAvgY,
            "rHist" to rHist.clone(), // Clone primitive arrays to avoid concurrency issues during channel serialization
            "gHist" to gHist.clone(), 
            "bHist" to bHist.clone(), 
            "maxVal" to maxV
        )
        textureView.post { eventSink?.success(data); isProcessing = false }
    }

    private fun startBackgroundThread() {
        if (backgroundThread != null) return
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try { backgroundThread?.join(); backgroundThread = null; backgroundHandler = null } catch (e: Exception) {}
    }

    private fun closeCamera() {
        captureSession?.close(); captureSession = null
        stillSession?.close(); stillSession = null
        stillImageReader?.close(); stillImageReader = null
        cameraDevice?.close(); cameraDevice = null
        imageReader?.close(); imageReader = null
        synchronized(captureLock) { captureResultCallback = null }
    }
}
