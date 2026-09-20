package com.tajeerai.mobile.callerid

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CallerIdPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(readPermissionStatus())
            "requestCallScreeningRole" -> result.success(requestCallScreeningRole())
            "openOverlaySettings" -> {
                openOverlaySettings()
                result.success(null)
            }
            "syncSettings" -> {
                CallerIdPreferences(appContext).writeSettings(call.arguments)
                result.success(null)
            }
            "syncRuntimeConfig" -> {
                CallerIdPreferences(appContext).writeRuntimeConfig(call.arguments)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun readPermissionStatus(): Map<String, Any> {
        val roleHeld = CallerIdRoleManager(appContext).isCallScreeningRoleHeld()
        val overlay = Settings.canDrawOverlays(appContext)
        val available = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

        return mapOf(
            "callScreeningRoleHeld" to roleHeld,
            "canDrawOverlays" to overlay,
            "callScreeningAvailable" to available,
        )
    }

    private fun requestCallScreeningRole(): Boolean {
        val currentActivity = activity ?: return false

        return CallerIdRoleManager(appContext).requestCallScreeningRole(currentActivity)
    }

    private fun openOverlaySettings() {
        val currentActivity = activity ?: return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${appContext.packageName}"),
        )
        currentActivity.startActivity(intent)
    }

    companion object {
        private const val CHANNEL = "com.tajeerai.mobile/caller_id"
    }
}
