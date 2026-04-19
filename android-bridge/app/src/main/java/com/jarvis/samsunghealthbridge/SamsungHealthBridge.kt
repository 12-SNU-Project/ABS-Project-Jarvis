package com.jarvis.samsunghealthbridge

import android.app.Activity
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.error.ResolvablePlatformException
import org.json.JSONObject

private const val DEFAULT_SLEEP_RANGE_DAYS = 7L

class SamsungHealthBridge(
    private val activity: Activity,
    private val statusSink: (String) -> Unit,
) {
    private var store: HealthDataStore? = null
    private var connected = false

    fun connect() {
        statusSink("Connecting Samsung Health...")
        runCatching {
            store = HealthDataService.getStore(activity)
            connected = true
            statusSink("Samsung Health connected")
        }.onFailure { error ->
            connected = false
            if (error is ResolvablePlatformException && error.hasResolution) {
                error.resolve(activity)
                statusSink("Resolve Samsung Health connection on device")
            } else {
                statusSink("Connection failed: ${error.message ?: error::class.java.simpleName}")
            }
        }
    }

    fun disconnect() {
        store = null
        connected = false
    }

    suspend fun requestSleepPermission() {
        val activeStore = requireStore()

        runCatching {
            activeStore.requestPermissions(
                SamsungHealthSdkCompat.sleepReadPermissions(),
                activity,
            )
            statusSink("Samsung Health sleep permission granted")
        }.onFailure { error ->
            if (error is ResolvablePlatformException && error.hasResolution) {
                error.resolve(activity)
                statusSink("Resolve Samsung Health permission on device")
            } else {
                throw error
            }
        }
    }

    suspend fun readRecentSleepAndUpload(
        backendBaseUrl: String,
        bridgeToken: String,
        rangeDays: Long = DEFAULT_SLEEP_RANGE_DAYS,
    ): JSONObject {
        val result = SamsungHealthBridgeRepository.readAndUploadRecentSleep(
            context = activity,
            backendBaseUrl = backendBaseUrl,
            bridgeToken = bridgeToken,
            rangeDays = rangeDays,
        )
        result.latestWakeTimeMs?.let {
            BridgePreferences.setLastUploadedWakeTimeMs(activity, it)
        }
        return result.backendResponse
    }

    private fun requireStore(): HealthDataStore {
        return checkNotNull(store) { "Connect Samsung Health first." }
    }
}
