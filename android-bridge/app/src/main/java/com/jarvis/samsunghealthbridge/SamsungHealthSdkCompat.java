package com.jarvis.samsunghealthbridge;

import com.samsung.android.sdk.health.data.t;
import com.samsung.android.sdk.health.data.permission.AccessType;
import com.samsung.android.sdk.health.data.permission.Permission;
import com.samsung.android.sdk.health.data.request.DataType;

import java.util.Collections;
import java.util.Set;

final class SamsungHealthSdkCompat {
    private SamsungHealthSdkCompat() {
    }

    static DataType.SleepType sleepType() {
        return (DataType.SleepType) t.b("sleep");
    }

    static Set<Permission> sleepReadPermissions() {
        return Collections.singleton(Permission.of(sleepType(), AccessType.READ));
    }
}
