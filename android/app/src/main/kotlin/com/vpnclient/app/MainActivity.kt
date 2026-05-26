package com.vpnclient.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.vpnclient.app/vpn"
        private const val VPN_REQUEST_CODE = 42
    }

    private var pendingConfig: String? = null
    private var pendingSocksPort: Int = 10808
    private var pendingHttpPort: Int = 10809
    private var pendingBypassLan: Boolean = true
    private var methodResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wire up VPN state callbacks
        SwiftVpnService.stateCallback = { state ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onStateChanged", state)
        }
        SwiftVpnService.errorCallback = { error ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onError", error)
        }

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
                        methodResult = result

                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            doStartVpn()
                            result.success(true)
                        }
                    }
                    "stopVpn" -> {
                        doStopVpn()
                        result.success(true)
                    }
                    "getStats" -> {
                        result.success(mapOf("upload" to 0L, "download" to 0L))
                    }
                    "isRunning" -> {
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                doStartVpn()
                methodResult?.success(true)
            } else {
                methodResult?.error("PERMISSION_DENIED", "VPN permission denied", null)
            }
            methodResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun doStartVpn() {
        val intent = Intent(this, SwiftVpnService::class.java).apply {
            action = SwiftVpnService.ACTION_START
            putExtra("config", pendingConfig)
            putExtra("socksPort", pendingSocksPort)
            putExtra("httpPort", pendingHttpPort)
            putExtra("bypassLan", pendingBypassLan)
        }
        startService(intent)
    }

    private fun doStopVpn() {
        val intent = Intent(this, SwiftVpnService::class.java).apply {
            action = SwiftVpnService.ACTION_STOP
        }
        startService(intent)
    }
}
