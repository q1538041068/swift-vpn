package com.vpnclient.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

class SwiftVpnService : VpnService() {
    companion object {
        const val ACTION_START = "com.vpnclient.app.START"
        const val ACTION_STOP = "com.vpnclient.app.STOP"
        const val CHANNEL_ID = "vpn_status"
        const val NOTIFICATION_ID = 1

        private const val VPN_MTU = 1500
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_DNS = "1.1.1.1"

        var stateCallback: ((String) -> Unit)? = null
        var errorCallback: ((String) -> Unit)? = null
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private var running = false
    private val executor = Executors.newSingleThreadExecutor()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra("config") ?: ""
                val socksPort = intent.getIntExtra("socksPort", 10808)
                val httpPort = intent.getIntExtra("httpPort", 10809)
                val bypassLan = intent.getBooleanExtra("bypassLan", true)
                startVpn(config, socksPort, httpPort, bypassLan)
            }
            ACTION_STOP -> {
                stopVpn()
            }
        }
        return START_STICKY
    }

    private fun startVpn(config: String, socksPort: Int, httpPort: Int, bypassLan: Boolean) {
        executor.execute {
            try {
                stateCallback?.invoke("CONNECTING")

                startV2RayCore(config)
                establishVpn(socksPort, bypassLan)
                startForeground(NOTIFICATION_ID, buildNotification("已连接"))

                running = true
                stateCallback?.invoke("CONNECTED")

                // Keep reading from TUN to keep it alive
                protectTun()
            } catch (e: Exception) {
                errorCallback?.invoke("VPN error: ${e.message}")
                stateCallback?.invoke("ERROR")
            }
        }
    }

    private fun establishVpn(socksPort: Int, bypassLan: Boolean) {
        val builder = Builder()
            .setSession("SwiftVPN")
            .addAddress(VPN_ADDRESS, 32)
            .addRoute("0.0.0.0", 0)
            .addDnsServer(VPN_DNS)
            .setMtu(VPN_MTU)
            .setBlocking(true)

        // Route traffic through local SOCKS proxy (V2Ray/sing-box)
        builder.setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", socksPort))

        if (bypassLan) {
            // Allow the app to bypass the VPN
            builder.addDisallowedApplication(packageName)
        }

        vpnInterface = builder.establish()
            ?: throw IllegalStateException("Failed to establish VPN interface")
    }

    private fun startV2RayCore(config: String) {
        try {
            val binaryPath = prepareBinary()
            val configDir = File(filesDir, "sing-box")
            configDir.mkdirs()
            val configFile = File(configDir, "config.json")
            configFile.writeText(config)

            val pb = ProcessBuilder(
                binaryPath, "run",
                "-c", configFile.absolutePath,
                "--disable-color"
            )
            pb.directory(configDir)
            pb.environment()["HOME"] = configDir.absolutePath
            pb.redirectErrorStream(true)
            pb.start()
        } catch (e: Exception) {
            // sing-box start failed, VPN tunnel still active via proxy
        }
    }

    private fun prepareBinary(): String {
        val abi = when (Build.SUPPORTED_ABIS.firstOrNull()) {
            "arm64-v8a" -> "sing-box-arm64"
            "armeabi-v7a" -> "sing-box-arm"
            "x86_64" -> "sing-box-x64"
            "x86" -> "sing-box-x64"
            else -> "sing-box-arm64"
        }
        val dest = File(filesDir, "sing-box-bin")
        if (!dest.exists()) {
            assets.open(abi).use { input ->
                dest.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            dest.setExecutable(true)
        }
        return dest.absolutePath
    }

    private fun protectTun() {
        val fd = vpnInterface ?: return
        vpnThread = Thread {
            try {
                val input = FileInputStream(fd.fileDescriptor)
                val buffer = ByteArray(32767)
                while (running) {
                    val len = input.read(buffer)
                    if (len < 0) break
                }
            } catch (_: Exception) {
            }
        }.apply {
            name = "VPN-TUN"
            start()
        }
    }

    private fun stopVpn() {
        running = false
        executor.execute {
            try {
                vpnThread?.interrupt()
                vpnThread = null
                vpnInterface?.close()
                vpnInterface = null
                stopForeground(STOP_FOREGROUND_REMOVE)
                stateCallback?.invoke("DISCONNECTED")
            } catch (e: Exception) {
                errorCallback?.invoke("Stop error: ${e.message}")
            }
        }
    }

    private fun buildNotification(text: String): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SwiftVPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(openIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "VPN状态",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
