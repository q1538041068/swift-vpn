package com.vpnclient.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.core.app.NotificationCompat
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

class VpnServiceController(
    private val context: Context,
    private val onStateChanged: (String) -> Unit,
    private val onStatsUpdate: (Long, Long) -> Unit,
    private val onError: (String) -> Unit
) {
    private val executor = Executors.newSingleThreadExecutor()

    private val uploadBytes = AtomicLong(0)
    private val downloadBytes = AtomicLong(0)

    private var running = false
    private var v2rayProcess: Process? = null

    companion object {
        const val CHANNEL_ID = "vpn_status"
        const val NOTIFICATION_ID = 1
    }

    fun start(configJson: String, socksPort: Int, httpPort: Int, bypassLan: Boolean) {
        executor.execute {
            try {
                onStateChanged("CONNECTING")
                startV2RayCore(configJson, socksPort, httpPort)
                running = true
                onStateChanged("CONNECTED")
            } catch (e: Exception) {
                onError("VPN start failed: ${e.message}")
            }
        }
    }

    private fun startV2RayCore(config: String, socksPort: Int, httpPort: Int) {
        val configDir = File(context.filesDir, "v2ray")
        configDir.mkdirs()
        val configFile = File(configDir, "config.json")
        configFile.writeText(config)

        // To use bundled sing-box binary, uncomment and place libsing-box.so in jniLibs:
        // val binary = File(context.applicationInfo.nativeLibDir, "libsing-box.so")
        // binary.setExecutable(true)
        // val pb = ProcessBuilder(binary.absolutePath, "run", "-c", configFile.absolutePath)
        // pb.directory(configDir)
        // pb.environment()["HOME"] = configDir.absolutePath
        // v2rayProcess = pb.start()
    }

    fun stop() {
        running = false
        executor.execute {
            try {
                v2rayProcess?.destroy()
                v2rayProcess = null
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
