package com.vpnclient.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.vpnclient.app/vpn"
        private const val VPN_REQUEST_CODE = 42
    }

    private var vpnController: VpnServiceController? = null
    private var pendingConfig: String? = null
    private var methodResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val config = call.argument<String>("config") ?: ""
                    val socksPort = call.argument<Int>("socksPort") ?: 10808
                    val httpPort = call.argument<Int>("httpPort") ?: 10809
                    val bypassLan = call.argument<Boolean>("bypassLan") ?: true

                    pendingConfig = config
                    methodResult = result

                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        startVpnInternal(config, socksPort, httpPort, bypassLan)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    vpnController?.stop()
                    vpnController = null
                    result.success(true)
                }
                "getStats" -> {
                    val stats = vpnController?.getStats()
                    result.success(stats)
                }
                "isRunning" -> {
                    result.success(vpnController?.isRunning() ?: false)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                val config = pendingConfig ?: ""
                // Extract ports from last call (simplified — in production store these)
                startVpnInternal(config, 10808, 10809, true)
                methodResult?.success(true)
            } else {
                methodResult?.error("PERMISSION_DENIED", "VPN permission denied", null)
            }
            pendingConfig = null
            methodResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun startVpnInternal(
        config: String,
        socksPort: Int,
        httpPort: Int,
        bypassLan: Boolean
    ) {
        vpnController = VpnServiceController(
            this,
            onStateChanged = { state ->
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    CHANNEL
                ).invokeMethod("onStateChanged", state)
            },
            onStatsUpdate = { upload, download ->
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    CHANNEL
                ).invokeMethod("onStatsUpdate", mapOf(
                    "upload" to upload,
                    "download" to download
                ))
            },
            onError = { error ->
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    CHANNEL
                ).invokeMethod("onError", error)
            }
        )
        vpnController?.start(config, socksPort, httpPort, bypassLan)
    }

    override fun onDestroy() {
        vpnController?.stop()
        super.onDestroy()
    }
}
