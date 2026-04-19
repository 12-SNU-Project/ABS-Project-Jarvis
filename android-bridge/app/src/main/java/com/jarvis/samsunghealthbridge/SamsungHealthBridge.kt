package com.jarvis.samsunghealthbridge

import android.app.Activity
import android.util.Log
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.error.ResolvablePlatformException
import com.samsung.android.sdk.health.data.helper.read
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.LocalTimeFilter
import com.samsung.android.sdk.health.data.request.Ordering
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

private const val DEFAULT_SLEEP_RANGE_DAYS = 7L

class SamsungHealthBridge(
    private val activity: Activity,
    private val statusSink: (String) -> Unit,
) {
    private val client = OkHttpClient()
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
        val recentSleepRecords = readRecentSleepRecords(rangeDays)
        val payload = buildBridgePayload(recentSleepRecords, rangeDays)
        return uploadPayload(
            payload = payload,
            backendBaseUrl = backendBaseUrl,
            bridgeToken = bridgeToken,
        )
    }

    private suspend fun readRecentSleepRecords(rangeDays: Long): JSONArray = withContext(Dispatchers.IO) {
        val activeStore = requireStore()
        val sleepType = SamsungHealthSdkCompat.sleepType()
        val zoneId = ZoneId.systemDefault()
        val today = LocalDate.now(zoneId)
        val uniqueRecords = linkedMapOf<String, JSONObject>()

        for (offset in 0 until rangeDays) {
            val targetDate = today.minusDays(offset)
            val dayStart = targetDate.atStartOfDay()
            val dayEnd = targetDate.plusDays(1).atStartOfDay()

            val response = activeStore.read(sleepType) {
                this
                    .setOrdering(Ordering.DESC)
                    .setLocalTimeFilter(LocalTimeFilter.of(dayStart, dayEnd))
                    .setLimit(10)
            }

            response.dataList.forEach { point ->
                val startTime = point.startTime ?: return@forEach
                val endTime = point.endTime ?: return@forEach
                val zoneOffset = point.zoneOffset ?: return@forEach
                val key = "${startTime.toEpochMilli()}-${endTime.toEpochMilli()}"

                uniqueRecords[key] = JSONObject()
                    .put("start_time", startTime.toEpochMilli())
                    .put("end_time", endTime.toEpochMilli())
                    .put("time_offset", zoneOffset.totalSeconds * 1000)
                    .put("comment", "Imported from Samsung Health bridge")
            }
        }

        val records = JSONArray()
        uniqueRecords.values.forEach { records.put(it) }

        if (records.length() == 0) {
            throw IllegalStateException("No Samsung Health sleep records found in the requested range.")
        }

        return@withContext records
    }

    private fun buildBridgePayload(records: JSONArray, rangeDays: Long): JSONObject {
        return JSONObject()
            .put("health_data_type", "sleep")
            .put("status", "awake")
            .put("range_days", rangeDays)
            .put("items", records)
    }

    private suspend fun uploadPayload(
        payload: JSONObject,
        backendBaseUrl: String,
        bridgeToken: String,
    ): JSONObject = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${backendBaseUrl.trimEnd('/')}/api/v1/health/sleep/bridge")
            .addHeader("X-Bridge-Token", bridgeToken)
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                Log.e("SamsungHealthBridge", body)
                throw IllegalStateException("Bridge upload failed: ${response.code}")
            }
            return@withContext JSONObject(body)
        }
    }

    private fun requireStore(): HealthDataStore {
        return checkNotNull(store) { "Connect Samsung Health first." }
    }
}
