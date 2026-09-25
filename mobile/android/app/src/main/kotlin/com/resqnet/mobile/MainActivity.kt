package com.resqnet.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.resqnet.mobile.map.MapPlatformViewFactory
import com.resqnet.mobile.mesh.BleMeshManager
import com.resqnet.mobile.mesh.ResQNetBleMeshService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.MapLibre

class MainActivity : FlutterActivity() {

    companion object {
        private const val MESH_METHOD_CHANNEL = "com.resqnet.mobile/mesh"
        private const val MESH_EVENT_CHANNEL = "com.resqnet.mobile/mesh_events"
        private const val PERMISSION_REQUEST_CODE = 4410
    }

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize MapLibre Native SDK context
        MapLibre.getInstance(applicationContext)

        // Register platform view for native vector map
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.resqnet.mobile/vector_map",
            MapPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        val meshManager = BleMeshManager.getInstance(applicationContext)

        // 1. MethodChannel for Mesh Controls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMesh" -> {
                    val nodeId = call.argument<String>("nodeId") ?: "node_unknown"
                    ResQNetBleMeshService.start(applicationContext, nodeId)
                    meshManager.startMesh(nodeId)
                    result.success(true)
                }

                "stopMesh" -> {
                    meshManager.stopMesh()
                    ResQNetBleMeshService.stop(applicationContext)
                    result.success(true)
                }

                "broadcastPacket" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        val links = meshManager.broadcastPacket(bytes)
                        result.success(links)
                    } else {
                        result.error("INVALID_ARGS", "Bytes cannot be null", null)
                    }
                }

                "getMeshStatus" -> {
                    val status = mapOf(
                        "isActive" to meshManager.isRunning(),
                        "nodeId" to meshManager.getLocalNodeId(),
                        "peerCount" to meshManager.getActivePeerCount(),
                        "peers" to meshManager.getPeersList()
                    )
                    result.success(status)
                }

                "setDutyCycle" -> {
                    val lowPower = call.argument<Boolean>("lowPower") ?: false
                    meshManager.setDutyCycle(lowPower)
                    result.success(true)
                }

                "checkPermissions" -> {
                    result.success(hasRequiredPermissions())
                }

                "requestPermissions" -> {
                    if (hasRequiredPermissions()) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        requestRequiredPermissions()
                    }
                }

                "playEmergencyAlertSound" -> {
                    val freq = (call.argument<Double>("frequency") ?: 180.0)
                    val bursts = (call.argument<Int>("bursts") ?: 2)
                    playEmergencyAlertSound(freq, bursts)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // 2. EventChannel for Real-Time Radio Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    meshManager.listener = object : BleMeshManager.Listener {
                        override fun onPeerDiscovered(nodeId: String, address: String, rssi: Int) {
                            runOnUiThread {
                                eventSink?.success(
                                    mapOf(
                                        "event" to "PEER_DISCOVERED",
                                        "nodeId" to nodeId,
                                        "address" to address,
                                        "rssi" to rssi
                                    )
                                )
                            }
                        }

                        override fun onPeerConnected(nodeId: String, address: String) {
                            runOnUiThread {
                                eventSink?.success(
                                    mapOf(
                                        "event" to "PEER_CONNECTED",
                                        "nodeId" to nodeId,
                                        "address" to address
                                    )
                                )
                            }
                        }

                        override fun onPeerDisconnected(nodeId: String, address: String) {
                            runOnUiThread {
                                eventSink?.success(
                                    mapOf(
                                        "event" to "PEER_DISCONNECTED",
                                        "nodeId" to nodeId,
                                        "address" to address
                                    )
                                )
                            }
                        }

                        override fun onPacketReceived(packetBytes: ByteArray, fromAddress: String) {
                            runOnUiThread {
                                eventSink?.success(
                                    mapOf(
                                        "event" to "PACKET_RECEIVED",
                                        "bytes" to packetBytes,
                                        "from" to fromAddress
                                    )
                                )
                            }
                        }

                        override fun onStatusChanged(status: String) {
                            runOnUiThread {
                                eventSink?.success(
                                    mapOf(
                                        "event" to "STATUS_CHANGED",
                                        "status" to status
                                    )
                                )
                            }
                        }

                        override fun onMeshLog(message: String) {
                            runOnUiThread {
                                eventSink?.success(
                                    mapOf(
                                        "event" to "LOG",
                                        "message" to message
                                    )
                                )
                            }
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    meshManager.listener = null
                }
            }
        )
    }

    private fun hasRequiredPermissions(): Boolean {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        return permissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun playEmergencyAlertSound(frequencyHz: Double = 180.0, bursts: Int = 2) {
        Thread {
            try {
                val sampleRate = 44100
                val burstDurationMs = 350
                val pauseDurationMs = 120
                val burstSamples = (sampleRate * (burstDurationMs / 1000.0)).toInt()
                val pauseSamples = (sampleRate * (pauseDurationMs / 1000.0)).toInt()
                val totalSamples = (burstSamples * bursts) + (pauseSamples * (bursts - 1))

                val soundData = ShortArray(totalSamples)
                var offset = 0

                for (b in 0 until bursts) {
                    for (i in 0 until burstSamples) {
                        val time = i.toDouble() / sampleRate
                        val angle = 2.0 * Math.PI * frequencyHz * time
                        val harmonicAngle = 2.0 * Math.PI * (frequencyHz * 2.0) * time
                        val sampleValue = 0.75 * Math.sin(angle) + 0.25 * Math.sin(harmonicAngle)
                        val envelope = when {
                            i < 500 -> i / 500.0
                            i > burstSamples - 500 -> (burstSamples - i) / 500.0
                            else -> 1.0
                        }
                        soundData[offset++] = (sampleValue * envelope * Short.MAX_VALUE * 1.0).toInt().toShort()
                    }
                    if (b < bursts - 1) {
                        for (i in 0 until pauseSamples) {
                            soundData[offset++] = 0
                        }
                    }
                }

                // Ensure ALARM stream volume is set to 100% maximum
                val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as? android.media.AudioManager
                audioManager?.let { am ->
                    try {
                        val maxVol = am.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM)
                        am.setStreamVolume(android.media.AudioManager.STREAM_ALARM, maxVol, 0)
                    } catch (e: Exception) {
                        Log.w("MainActivity", "Could not adjust STREAM_ALARM volume: ${e.message}")
                    }
                }

                val audioTrack = android.media.AudioTrack(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                    android.media.AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                    soundData.size * 2,
                    android.media.AudioTrack.MODE_STATIC,
                    android.media.AudioManager.AUDIO_SESSION_ID_GENERATE
                )
                audioTrack.setVolume(1.0f)
                audioTrack.write(soundData, 0, soundData.size)
                audioTrack.play()

                // Emergency haptic vibration pulse
                val vibrator = getSystemService(android.content.Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(android.os.VibrationEffect.createWaveform(longArrayOf(0, 350, 120, 350), -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(longArrayOf(0, 350, 120, 350), -1)
                }

                Thread.sleep(burstDurationMs * bursts.toLong() + pauseDurationMs * (bursts - 1).toLong() + 250)
                audioTrack.stop()
                audioTrack.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }
}
