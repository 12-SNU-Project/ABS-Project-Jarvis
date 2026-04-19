package com.jarvis.samsunghealthbridge

import android.content.Context

object BridgePreferences {
    private const val PREFS_NAME = "samsung_health_bridge_prefs"
    private const val KEY_BACKEND_URL = "backend_url"
    private const val KEY_BRIDGE_TOKEN = "bridge_token"
    private const val KEY_AUTO_SYNC_ENABLED = "auto_sync_enabled"
    private const val KEY_LAST_UPLOADED_WAKE_TIME_MS = "last_uploaded_wake_time_ms"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getBackendUrl(context: Context): String =
        prefs(context).getString(KEY_BACKEND_URL, BuildConfig.BACKEND_BASE_URL).orEmpty()

    fun getBridgeToken(context: Context): String =
        prefs(context).getString(KEY_BRIDGE_TOKEN, BuildConfig.BRIDGE_TOKEN).orEmpty()

    fun saveBackendConfig(context: Context, backendUrl: String, bridgeToken: String) {
        prefs(context).edit()
            .putString(KEY_BACKEND_URL, backendUrl)
            .putString(KEY_BRIDGE_TOKEN, bridgeToken)
            .apply()
    }

    fun isAutoSyncEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_AUTO_SYNC_ENABLED, false)

    fun setAutoSyncEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit()
            .putBoolean(KEY_AUTO_SYNC_ENABLED, enabled)
            .apply()
    }

    fun getLastUploadedWakeTimeMs(context: Context): Long =
        prefs(context).getLong(KEY_LAST_UPLOADED_WAKE_TIME_MS, -1L)

    fun setLastUploadedWakeTimeMs(context: Context, value: Long) {
        prefs(context).edit()
            .putLong(KEY_LAST_UPLOADED_WAKE_TIME_MS, value)
            .apply()
    }
}
