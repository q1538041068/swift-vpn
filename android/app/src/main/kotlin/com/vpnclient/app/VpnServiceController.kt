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
import java.lang.ref.WeakReference
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

class VpnServiceController(
    context: Context,
    private val onStateChanged: (String) -> Unit,
    private val onStatsUpdate: (Long, Long) -> Unit,
    private val onError: (String) -> Unit
) {
    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private var running = false

    private val uploadBytes = AtomicLong(0)
    private val downloadBytes = AtomicLong(0)

    companion object {
        private const val VPN_MTU = 1500
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_ROUTE = "0.0.0.0"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_status"
    }

    // Placeholder for V2Ray/sing-box core integration
    // In production, this would start a tun2socks + V2Ray process
    private var v2rayProcess: Process? = null

    fun start(config: String, socksPort: Int, httpPort: Int, bypassLan: Boolean) {
        executor.execute {
            try {
                onStateChanged("CONNECTING")
                startV2RayCore(config, socksPort, httpPort)
                establishVpn(socksPort, bypassLan)
                running = true
                onStateChanged("CONNECTED")
            } catch (e: Exception) {
                onError("VPN start failed: ${e.message}")
            }
        }
    }

    private fun startV2RayCore(config: String, socksPort: Int, httpPort: Int) {
        // Write config to a temp file for V2Ray/sing-box to read
        val configDir = File(appContext.filesDir, "v2ray")
        configDir.mkdirs()
        val configFile = File(configDir, "config.json")
        configFile.writeText(config)

        // In production, this starts the V2Ray/sing-box binary bundled with the APK
        // The binary reads config.json and listens on socksPort/httpPort
        // For now, we set up the TUN device that routes traffic through the local SOCKS proxy

        // Example with bundled sing-box:
        // val binary = File(appContext.applicationInfo.nativeLibDir, "libsing-box.so")
        // binary.setExecutable(true)
        // val pb = ProcessBuilder(binary.absolutePath, "run", "-c", configFile.absolutePath)
        // pb.directory(configDir)
        // pb.environment()["HOME"] = configDir.absolutePath
        // v2rayProcess = pb.start()
    }

    private fun establishVpn(socksPort: Int, bypassLan: Boolean) {
        val builder = android.net.VpnService.Builder()
            .setSession("SwiftVPN")
            .addAddress(VPN_ADDRESS, 32)
            .addRoute(VPN_ROUTE, 0)
            .setMtu(VPN_MTU)
            .setBlocking(true)

        if (bypassLan) {
            // Bypass private IP ranges
            builder.addDisallowedApplication(appContext.packageName)
        }

        // Route traffic through local SOCKS proxy
        builder.setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", socksPort))

        vpnInterface = builder.establish()
            ?: throw IllegalStateException("VPN interface establishment failed")

        startForegroundNotification()
    }

    private fun startForegroundNotification() {
        val manager =
            appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val openIntent = appContext.packageManager
            .getLaunchIntentForPackage(appContext.packageName)
        val pendingIntent = PendingIntent.getActivity(
            appContext,
            0,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setContentTitle("SwiftVPN")
            .setContentText("VPN 已连接")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        // In a real implementation, this would run in a VpnService subclass
        // For Flutter integration, we manage it here
    }

    fun stop() {
        running = false
        executor.execute {
            try {
                v2rayProcess?.destroy()
                v2rayProcess = null
                vpnInterface?.close()
                vpnInterface = null
                onStateChanged("DISCONNECTED")
            } catch (e: Exception) {
                onError("VPN stop error: ${e.message}")
            }
        }
    }

    fun isRunning(): Boolean = running

    fun getStats(): Map<String, Long> = mapOf(
        "upload" to uploadBytes.get(),
        "download" to downloadBytes.get()
    )
}
