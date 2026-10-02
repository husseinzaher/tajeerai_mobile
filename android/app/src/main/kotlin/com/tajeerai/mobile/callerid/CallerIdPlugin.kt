package com.tajeerai.mobile.callerid

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * The Flutter side of Caller ID: permissions, the screening role, and the
 * settings the native service reads while Flutter is not running.
 *
 * ## Why contacts are a Caller ID permission
 *
 * Telecom only hands a call to a screening app when the caller is *not* in
 * the phone's contacts - unless the app holds `READ_CONTACTS`, in which case
 * it is consulted for every call (`CallScreeningServiceFilter` skips the
 * bind otherwise, in a millisecond and without a word). A merchant's customers
 * are very often also in their phone, so without this permission the card
 * appears only for strangers, which reads as "it does not work".
 */
class CallerIdPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val pendingResults = mutableMapOf<Int, MethodChannel.Result>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detach()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onDetachedFromActivity() {
        detach()
    }

    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detach() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
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
            "requestContactsPermission" ->
                requestPermission(Manifest.permission.READ_CONTACTS, CONTACTS_REQUEST_CODE, result)
            "requestPhoneStatePermission" ->
                requestPermission(Manifest.permission.READ_PHONE_STATE, PHONE_STATE_REQUEST_CODE, result)
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
            "readContactsGranted" to has(Manifest.permission.READ_CONTACTS),
            // Lets the card follow the call to its end and show a summary.
            "readPhoneStateGranted" to has(Manifest.permission.READ_PHONE_STATE),
        )
    }

    private fun has(permission: String): Boolean =
        appContext.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /**
     * Resolves with whether the permission is held once the system dialog
     * closes. Already granted resolves at once; no activity resolves false
     * rather than hanging a settings screen on a dialog that cannot open.
     */
    private fun requestPermission(permission: String, requestCode: Int, result: MethodChannel.Result) {
        if (has(permission)) {
            result.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.success(false)
            return
        }

        // A second request while one is open answers the first as refused,
        // so the channel never holds a Result it will not complete.
        pendingResults.remove(requestCode)?.success(false)
        pendingResults[requestCode] = result
        currentActivity.requestPermissions(arrayOf(permission), requestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        val pending = pendingResults.remove(requestCode) ?: return false

        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending.success(granted)
        return true
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
        private const val CONTACTS_REQUEST_CODE = 9102
        private const val PHONE_STATE_REQUEST_CODE = 9103
    }
}
