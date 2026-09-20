package com.tajeerai.mobile.callerid

import android.content.Context

class CallerIdPreferences(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun writeSettings(arguments: Any?) {
        if (arguments !is Map<*, *>) return

        val editor = prefs.edit()
        for ((key, value) in arguments) {
            when (value) {
                is Boolean -> editor.putBoolean(key.toString(), value)
                is Int -> editor.putInt(key.toString(), value)
                is Long -> editor.putLong(key.toString(), value)
                is Double -> editor.putFloat(key.toString(), value.toFloat())
                is Float -> editor.putFloat(key.toString(), value)
                is String -> editor.putString(key.toString(), value)
            }
        }
        editor.apply()
    }

    fun writeRuntimeConfig(arguments: Any?) {
        if (arguments !is Map<*, *>) return

        val editor = prefs.edit()
        arguments["databasePath"]?.toString()?.let { editor.putString(KEY_DB_PATH, it) }
        arguments["apiBaseUrl"]?.toString()?.let { editor.putString(KEY_API_BASE, it) }
        arguments["accessToken"]?.toString()?.let { editor.putString(KEY_ACCESS_TOKEN, it) }
        editor.apply()
    }

    fun isEnabled(): Boolean = prefs.getBoolean("enabled", false)

    fun shouldShowIncoming(): Boolean = prefs.getBoolean("showIncoming", true)

    fun shouldShowOutgoing(): Boolean = prefs.getBoolean("showOutgoing", true)

    fun shouldShowOnlyUnknown(): Boolean = prefs.getBoolean("showOnlyUnknown", false)

    fun shouldShowContacts(): Boolean = prefs.getBoolean("showContacts", true)

    fun autoDismissSeconds(): Int = prefs.getInt("autoDismissSeconds", 15)

    fun cardEnabled(): Boolean = prefs.getBoolean("cardEnabled", true)

    fun cardPosition(): String = prefs.getString("cardPosition", "top") ?: "top"

    fun cardSize(): String = prefs.getString("cardSize", "compact") ?: "compact"

    fun showAvatar(): Boolean = prefs.getBoolean("showAvatar", true)

    fun showCallerName(): Boolean = prefs.getBoolean("showCallerName", true)

    fun showPhoneNumber(): Boolean = prefs.getBoolean("showPhoneNumber", true)

    fun showTags(): Boolean = prefs.getBoolean("showTags", true)

    fun showSpamStatus(): Boolean = prefs.getBoolean("showSpamStatus", true)

    fun showBusinessInfo(): Boolean = prefs.getBoolean("showBusinessInfo", true)

    fun animationEnabled(): Boolean = prefs.getBoolean("animationEnabled", true)

    fun dismissOnTap(): Boolean = prefs.getBoolean("dismissOnTap", true)

    fun showOverOtherApps(): Boolean = prefs.getBoolean("showOverOtherApps", true)

    fun localLookupEnabled(): Boolean = prefs.getBoolean("localLookupEnabled", true)

    fun serverLookupEnabled(): Boolean = prefs.getBoolean("serverLookupEnabled", true)

    fun useCachedData(): Boolean = prefs.getBoolean("useCachedData", true)

    fun databasePath(): String? = prefs.getString(KEY_DB_PATH, null)

    fun apiBaseUrl(): String? = prefs.getString(KEY_API_BASE, null)

    fun accessToken(): String? = prefs.getString(KEY_ACCESS_TOKEN, null)

    companion object {
        private const val PREFS_NAME = "caller_id_settings"
        private const val KEY_DB_PATH = "runtime.databasePath"
        private const val KEY_API_BASE = "runtime.apiBaseUrl"
        private const val KEY_ACCESS_TOKEN = "runtime.accessToken"
    }
}
