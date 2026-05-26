package com.vpnclient.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.vpnclient.app/vpn"
        private const val VPN_REQUEST_CODE = 42
    }

    private var vpnController: VpnServiceController? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingConfig: String? = null
    private var pendingSocksPort: Int = 10808
    private var pendingHttpPort: Int = 10809
    private var pendingBypassLan: Boolean = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVpn" -> {
                        val config = call.argument<String>("config") ?: ""
                        val socksPort = call.argument<Int>("socksPort") ?: 10808
                        val httpPort = call.argument<Int>("httpPort") ?: 10809
                        val bypassLan = call.argument<Boolean>("bypassLan") ?: true

                        pendingConfig = config
                        pendingSocksPort = socksPort
                        pendingHttpPort = httpPort
                        pendingBypassLan = bypassLan
                        pendingResult = result

                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            doStartVpn()
                            result.success(true)
                        }
                    }
                    "stopVpn" -> {
                        vpnController?.stop()
                        vpnController = null
                        result.success(true)
                    }
                    "getStats" -> {
                        result.success(vpnController?.getStats())
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
                doStartVpn()
                pendingResult?.success(true)
            } else {
                pendingResult?.error("PERMISSION_DENIED", "VPN permission denied", null)
            }
            pendingResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun doStartVpn() {
        val config = pendingConfig ?: return
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
        vpnController?.start(config, pendingSocksPort, pendingHttpPort, pendingBypassLan)
    }

    override fun onDestroy() {
        vpnController?.stop()
        super.onDestroy()
    }
}
