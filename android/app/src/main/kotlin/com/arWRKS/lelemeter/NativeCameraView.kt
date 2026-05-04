package com.arWRKS.lelemeter

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.MeteringRectangle
import android.media.ImageReader
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
import java.util.Arrays
import kotlin.math.log2
import kotlin.math.pow
import kotlin.math.max
import kotlin.math.min

class NativeCameraView(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String?, Any?>?
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val textureView: TextureView = TextureView(context)
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private val cameraManager: CameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var cameraId: String = ""

    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    private var eventSink: EventChannel.EventSink? = null
    private val methodChannel: MethodChannel
    private val eventChannel: EventChannel

    // AE-L State
    private var isAELocked = false
    private var lockedAvgY = 128.0
    private var lockedBaseEV = 8.0
    private var currentAvgY = 128.0
    
    // Spot Metering (0.0 to 1.0)
    private var meteringX = -1.0
    private var meteringY = -1.0
    private var zoomLevel = 1.0f
    
    // Hardware Exposure State
    private var currentIso = 100
    private var currentShutterNs = 10000000L // 1/100s

    // The init block is moved to the bottom of the class.

    override fun getView(): View {
        return textureView
    }

    override fun dispose() {
        closeCamera()
        stopBackgroundThread()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "lockAE" -> {
                isAELocked = true
                val baseEvArg = call.argument<Double>("baseEV") ?: 8.0
                lockedBaseEV = baseEvArg
                lockedAvgY = currentAvgY
                // Send command to Camera2 to lock AE
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
                result.success(null)
            }
            "setZoom" -> {
                zoomLevel = call.argument<Double>("zoom")?.toFloat() ?: 1.0f
                updatePreview()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private val surfaceTextureListener = object : TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
            openCamera()
        }
        override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}
        override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true
        override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
    }

    @SuppressLint("MissingPermission")
    private fun openCamera() {
        startBackgroundThread()
        try {
            // Find back camera
            for (id in cameraManager.cameraIdList) {
                val chars = cameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    cameraId = id
                    break
                }
            }
            if (cameraId.isEmpty() && cameraManager.cameraIdList.isNotEmpty()) {
                cameraId = cameraManager.cameraIdList[0]
            }

            cameraManager.openCamera(cameraId, stateCallback, backgroundHandler)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private val stateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            cameraDevice = camera
            createCameraPreviewSession()
        }
        override fun onDisconnected(camera: CameraDevice) {
            camera.close()
            cameraDevice = null
        }
        override fun onError(camera: CameraDevice, error: Int) {
            camera.close()
            cameraDevice = null
        }
    }

    private fun createCameraPreviewSession() {
        try {
            val texture = textureView.surfaceTexture ?: return
            texture.setDefaultBufferSize(640, 480) // Low res for faster processing
            val surface = Surface(texture)

            // Setup ImageReader for YUV processing
            imageReader = ImageReader.newInstance(640, 480, ImageFormat.YUV_420_888, 2)
            imageReader?.setOnImageAvailableListener(onImageAvailableListener, backgroundHandler)

            cameraDevice?.createCaptureSession(
                Arrays.asList(surface, imageReader?.surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        if (cameraDevice == null) return
                        captureSession = session
                        updatePreview()
                    }
                    override fun onConfigureFailed(session: CameraCaptureSession) {}
                },
                null
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updatePreview() {
        if (cameraDevice == null) return
        try {
            val captureRequestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            val texture = textureView.surfaceTexture ?: return
            captureRequestBuilder.addTarget(Surface(texture))
            
            imageReader?.surface?.let {
                captureRequestBuilder.addTarget(it)
            }

            // Auto Exposure Modes
            captureRequestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
            if (isAELocked) {
                captureRequestBuilder.set(CaptureRequest.CONTROL_AE_LOCK, true)
            } else {
                captureRequestBuilder.set(CaptureRequest.CONTROL_AE_LOCK, false)
            }

            val chars = cameraManager.getCameraCharacteristics(cameraId)
            val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            
            if (sensorRect != null) {
                // Zoom
                val cx = sensorRect.centerX()
                val cy = sensorRect.centerY()
                val dx = (sensorRect.width() / (2f * zoomLevel)).toInt()
                val dy = (sensorRect.height() / (2f * zoomLevel)).toInt()
                val cropRect = android.graphics.Rect(cx - dx, cy - dy, cx + dx, cy + dy)
                captureRequestBuilder.set(CaptureRequest.SCALER_CROP_REGION, cropRect)

                // AF/AE Regions
                if (meteringX >= 0.0 && meteringY >= 0.0) {
                    val tapX = (meteringY * sensorRect.width()).toInt()
                    val tapY = ((1.0 - meteringX) * sensorRect.height()).toInt()
                    val halfSize = sensorRect.width() / 10
                    val focusRect = android.graphics.Rect(
                        max(0, tapX - halfSize),
                        max(0, tapY - halfSize),
                        min(sensorRect.width(), tapX + halfSize),
                        min(sensorRect.height(), tapY + halfSize)
                    )
                    val meteringRect = MeteringRectangle(focusRect, MeteringRectangle.METERING_WEIGHT_MAX)
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(meteringRect))
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(meteringRect))
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_START)
                }
            }

            captureSession?.setRepeatingRequest(captureRequestBuilder.build(), captureCallback, backgroundHandler)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private val captureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
            super.onCaptureCompleted(session, request, result)
            val iso = result.get(CaptureResult.SENSOR_SENSITIVITY)
            val exposureTimeNs = result.get(CaptureResult.SENSOR_EXPOSURE_TIME)
            
            if (iso != null && exposureTimeNs != null) {
                currentIso = iso
                currentShutterNs = exposureTimeNs
            }
        }
    }

    private var lastProcessTime = 0L

    private val onImageAvailableListener = ImageReader.OnImageAvailableListener { reader ->
        val image = reader.acquireLatestImage() ?: return@OnImageAvailableListener
        
        // Throttle processing to ~20fps to save battery/CPU
        val now = System.currentTimeMillis()
        if (now - lastProcessTime < 50) {
            image.close()
            return@OnImageAvailableListener
        }
        lastProcessTime = now

        try {
            val planes = image.planes
            val yPlane = planes[0].buffer
            val uPlane = planes[1].buffer
            val vPlane = planes[2].buffer

            val width = image.width
            val height = image.height
            
            val yRowStride = planes[0].rowStride
            val uvRowStride = planes[1].rowStride
            val uvPixelStride = planes[1].pixelStride

            val rHist = IntArray(256)
            val gHist = IntArray(256)
            val bHist = IntArray(256)
            var maxVal = 1

            var totalY = 0L
            var samples = 0

            val skip = 8
            
            val yBytes = ByteArray(yPlane.remaining())
            yPlane.get(yBytes)
            val uBytes = ByteArray(uPlane.remaining())
            uPlane.get(uBytes)
            val vBytes = ByteArray(vPlane.remaining())
            vPlane.get(vBytes)

            // Spot Metering Area
            var startY = 0
            var endY = height
            var startX = 0
            var endX = width

            if (meteringX >= 0.0 && meteringY >= 0.0) {
                // Buffer is landscape, screen is portrait
                val tapBufferX = (meteringY * width).toInt()
                val tapBufferY = ((1.0 - meteringX) * height).toInt()
                val boxSize = width / 6
                startX = max(0, tapBufferX - boxSize)
                endX = min(width, tapBufferX + boxSize)
                startY = max(0, tapBufferY - boxSize)
                endY = min(height, tapBufferY + boxSize)
            }

            for (y in startY until endY step skip) {
                for (x in startX until endX step skip) {
                    val yIndex = y * yRowStride + x
                    val uvIndex = (y / 2) * uvRowStride + (x / 2) * uvPixelStride

                    if (yIndex >= yBytes.size || uvIndex >= uBytes.size || uvIndex >= vBytes.size) continue

                    val yp = yBytes[yIndex].toInt() and 0xFF
                    val up = (uBytes[uvIndex].toInt() and 0xFF) - 128
                    val vp = (vBytes[uvIndex].toInt() and 0xFF) - 128

                    val r = min(255, max(0, (yp + 1.370705f * vp).toInt()))
                    val g = min(255, max(0, (yp - 0.337633f * up - 0.698001f * vp).toInt()))
                    val b = min(255, max(0, (yp + 1.732446f * up).toInt()))

                    // Only add to histogram if we are sampling the whole frame or spot?
                    // Let's add to histogram anyway
                    rHist[r]++
                    gHist[g]++
                    bHist[b]++
                    
                    if (rHist[r] > maxVal) maxVal = rHist[r]
                    if (gHist[g] > maxVal) maxVal = gHist[g]
                    if (bHist[b] > maxVal) maxVal = bHist[b]

                    totalY += yp
                    samples++
                }
            }

            var frameAvgY = if (samples > 0) totalY.toDouble() / samples else 1.0
            if (frameAvgY < 1.0) frameAvgY = 1.0
            currentAvgY = frameAvgY

            // Calculate EV
            var calculatedEV = 0.0
            if (isAELocked) {
                val deltaEV = 2.2 * (log2(currentAvgY / lockedAvgY))
                calculatedEV = lockedBaseEV + deltaEV
            } else {
                // Base EV from hardware (100 ISO, 1s shutter = 0 EV)
                // EV = log2( (N^2)/t * (100/ISO) ) ... But we don't know Aperture!
                // Most phones have fixed aperture (e.g. f/1.8)
                // Let's use standard Lightmeter calculation but we don't know exact N.
                // We'll pass the hardware iso and shutter to flutter instead.
            }

            // Convert arrays for Flutter
            val rList = rHist.toList()
            val gList = gHist.toList()
            val bList = bHist.toList()

            // Send to UI thread
            Handler(android.os.Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "rHist" to rList,
                    "gHist" to gList,
                    "bHist" to bList,
                    "maxVal" to maxVal,
                    "avgY" to currentAvgY,
                    "iso" to currentIso,
                    "shutterNs" to currentShutterNs,
                    "calculatedEV" to calculatedEV,
                    "isLocked" to isAELocked
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            image.close()
        }
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            e.printStackTrace()
        }
    }

    private fun closeCamera() {
        captureSession?.close()
        captureSession = null
        cameraDevice?.close()
        cameraDevice = null
        imageReader?.close()
        imageReader = null
    }

    init {
        methodChannel = MethodChannel(messenger, "com.arWRKS.lelemeter/camera_methods_$id")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(messenger, "com.arWRKS.lelemeter/camera_events_$id")
        eventChannel.setStreamHandler(this)

        textureView.surfaceTextureListener = surfaceTextureListener
    }
}
