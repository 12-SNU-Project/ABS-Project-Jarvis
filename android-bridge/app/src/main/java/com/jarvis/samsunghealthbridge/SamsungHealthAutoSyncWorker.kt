package com.jarvis.samsunghealthbridge

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.Constraints
import java.util.concurrent.TimeUnit

class SamsungHealthAutoSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        if (!BridgePreferences.isAutoSyncEnabled(applicationContext)) {
            return Result.success()
        }

        val backendUrl = BridgePreferences.getBackendUrl(applicationContext)
        val bridgeToken = BridgePreferences.getBridgeToken(applicationContext)
        if (backendUrl.isBlank() || bridgeToken.isBlank()) {
            return Result.failure()
        }

        return runCatching {
            val payload = SamsungHealthBridgeRepository.readRecentSleepPayload(
                context = applicationContext,
                rangeDays = 7,
            )
            val latestWakeTimeMs = payload.optLong("latest_wake_time_ms", -1L)
            val lastUploadedWakeTimeMs = BridgePreferences.getLastUploadedWakeTimeMs(applicationContext)

            if (latestWakeTimeMs <= 0L || latestWakeTimeMs <= lastUploadedWakeTimeMs) {
                return Result.success()
            }

            SamsungHealthBridgeRepository.uploadSleepPayload(
                payload = payload,
                backendBaseUrl = backendUrl,
                bridgeToken = bridgeToken,
            )
            BridgePreferences.setLastUploadedWakeTimeMs(applicationContext, latestWakeTimeMs)
            Result.success()
        }.getOrElse {
            Result.retry()
        }
    }

    companion object {
        private const val WORK_NAME = "samsung-health-auto-sync"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<SamsungHealthAutoSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
