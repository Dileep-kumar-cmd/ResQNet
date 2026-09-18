package com.resqnet.mobile.mesh

import android.annotation.SuppressLint
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.resqnet.mobile.MainActivity
import com.resqnet.mobile.R

/**
 * Android Foreground Service for persistent offline BLE Mesh operation.
 * Keeps the BLE peripheral advertiser, GATT server, scanner, and peer relays active
 * even when the application is minimized or the screen is locked.
 */
class ResQNetBleMeshService : Service() {

    companion object {
        private const val TAG = "ResQNetBleMeshService"
        const val ACTION_START = "com.resqnet.mobile.mesh.START"
        const val ACTION_STOP = "com.resqnet.mobile.mesh.STOP"
        const val EXTRA_NODE_ID = "extra_node_id"

        private const val FOREGROUND_NOTIFICATION_ID = 9110
        private const val SOS_ALERT_NOTIFICATION_ID = 9119

        const val CHANNEL_ID_MESH = "resqnet_mesh_channel"
        const val CHANNEL_ID_SOS = "resqnet_sos_channel"

        @Volatile
        var isServiceRunning = false
            private set

        fun start(context: Context, nodeId: String) {
            val intent = Intent(context, ResQNetBleMeshService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_NODE_ID, nodeId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ResQNetBleMeshService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var meshManager: BleMeshManager
    private var currentNodeId = "node_offline"

    override fun onCreate() {
        super.onCreate()
        meshManager = BleMeshManager.getInstance(this)
        createNotificationChannels()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        if (action == ACTION_STOP) {
            stopForegroundService()
            return START_NOT_STICKY
        }

        val nodeId = intent?.getStringExtra(EXTRA_NODE_ID) ?: currentNodeId
        currentNodeId = nodeId

        // Start Foreground with Persistent Notification
        val notification = buildForegroundNotification("Node: $currentNodeId | Searching for peers...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                FOREGROUND_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(FOREGROUND_NOTIFICATION_ID, notification)
        }

        isServiceRunning = true
        meshManager.startMesh(currentNodeId)
        updateNotification()

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        meshManager.stopMesh()
        releaseWakeLock()
        isServiceRunning = false
        super.onDestroy()
    }

    fun updateNotification() {
        val peerCount = meshManager.getActivePeerCount()
        val text = "Node: $currentNodeId | Active Peers: $peerCount | Radio: Dual BLE"
        val notification = buildForegroundNotification(text)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(FOREGROUND_NOTIFICATION_ID, notification)
    }

    fun postSosAlertNotification(senderId: String, medicalNote: String, lat: Double, lon: Double) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID_SOS)
            .setContentTitle("🚨 EMERGENCY SOS BROADCAST RECEIVED")
            .setContentText("Sender: $senderId | Lat: $lat, Lon: $lon")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Emergency SOS received across BLE mesh!\n" +
                            "Sender: $senderId\n" +
                            "Location: $lat, $lon\n" +
                            "Details: $medicalNote"
                )
            )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        manager.notify(SOS_ALERT_NOTIFICATION_ID, notification)
    }

    private fun buildForegroundNotification(contentText: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID_MESH)
            .setContentTitle("ResQNet Mesh Active")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // 1. Mesh Background Service Channel (Low importance, silent)
            val meshChannel = NotificationChannel(
                CHANNEL_ID_MESH,
                "ResQNet Mesh Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows ongoing status of the offline P2P Bluetooth mesh network."
                setShowBadge(false)
            }
            manager?.createNotificationChannel(meshChannel)

            // 2. High-Priority SOS Channel (Heads-up, alert sounds)
            val sosChannel = NotificationChannel(
                CHANNEL_ID_SOS,
                "Emergency SOS Broadcast Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent disaster alerts received from nearby peer nodes."
                enableVibration(true)
                setShowBadge(true)
            }
            manager?.createNotificationChannel(sosChannel)
        }
    }

    @SuppressLint("WakelockTimeout")
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ResQNet::BleMeshWakeLock"
            )?.apply {
                acquire()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock: ${e.message}")
        }
    }

    private fun stopForegroundService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
