package com.jarvis.samsunghealthbridge

import android.content.Context
import android.util.Log
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.helper.read
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

data class SleepUploadResult(
    val payload: JSONObject,
    val latestWakeTimeMs: Long?,
    val backendResponse: JSONObject,
)

object SamsungHealthBridgeRepository {
    private val client = OkHttpClient()

    suspend fun readRecentSleepPayload(
        context: Context,
        rangeDays: Long,
    ): JSONObject = withContext(Dispatchers.IO) {
        val store = HealthDataService.getStore(context)
        val records = readRecentSleepRecords(store, rangeDays)
        val latestWakeTimeMs = buildList {
            for (index in 0 until records.length()) {
                val item = records.optJSONObject(index) ?: continue
                add(item.optLong("end_time"))
            }
        }.maxOrNull()

        return@withContext JSONObject()
            .put("health_data_type", "sleep")
            .put("detected_at", JSONObject.NULL)
            .put("range_days", rangeDays)
            .put("status", "awake")
            .put("items", records)
            .put("latest_wake_time_ms", latestWakeTimeMs)
    }

    suspend fun uploadSleepPayload(
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
                Log.e("SamsungHealthBridgeRepo", body)
                throw IllegalStateException("Bridge upload failed: ${response.code}")
            }
            return@withContext JSONObject(body)
        }
    }

    suspend fun readAndUploadRecentSleep(
        context: Context,
        backendBaseUrl: String,
        bridgeToken: String,
        rangeDays: Long,
    ): SleepUploadResult {
        val payload = readRecentSleepPayload(context, rangeDays)
        val backendResponse = uploadSleepPayload(payload, backendBaseUrl, bridgeToken)
        val latestWakeTimeMs = if (payload.has("latest_wake_time_ms")) {
            payload.optLong("latest_wake_time_ms")
        } else {
            null
        }
        return SleepUploadResult(
            payload = payload,
            latestWakeTimeMs = latestWakeTimeMs,
            backendResponse = backendResponse,
        )
    }

    private suspend fun readRecentSleepRecords(
        store: HealthDataStore,
        rangeDays: Long,
    ): JSONArray {
        val sleepType = SamsungHealthSdkCompat.sleepType()
        val zoneId = ZoneId.systemDefault()
        val today = LocalDate.now(zoneId)
        val uniqueRecords = linkedMapOf<String, JSONObject>()

        for (offset in 0 until rangeDays) {
            val targetDate = today.minusDays(offset)
            val dayStart = targetDate.atStartOfDay()
            val dayEnd = targetDate.plusDays(1).atStartOfDay()

            val response = store.read(sleepType) {
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
        return records
    }
}
