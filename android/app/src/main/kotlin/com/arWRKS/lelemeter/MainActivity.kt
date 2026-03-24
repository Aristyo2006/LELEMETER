package com.arWRKS.lelemeter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.hardware.Sensor
import android.hardware.SensorManager
import android.content.Context

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.arWRKS.lelemeter/sensor"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSensorName" -> {
                    val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
                    if (lightSensor != null) {
                        result.success(lightSensor.name)
                    } else {
                        result.error("UNAVAILABLE", "Light sensor not available.", null)
                    }
                }
                "restartApp" -> {
                    result.success(null)
                    this.recreate()
                }
                else -> result.notImplemented()
            }
        }
    }
}
