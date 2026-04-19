plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.parcelize")
}

val defaultBackendUrl = providers
    .environmentVariable("JARVIS_BACKEND_BASE_URL")
    .orElse("http://baemingyuui-MacBookAir.local:8000")
    .get()

val defaultBridgeToken = providers
    .environmentVariable("JARVIS_BRIDGE_TOKEN")
    .orElse("replace-me-123")
    .get()

android {
    namespace = "com.jarvis.samsunghealthbridge"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.jarvis.samsunghealthbridge"
        minSdk = 29
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"

        buildConfigField("String", "BACKEND_BASE_URL", "\"$defaultBackendUrl\"")
        buildConfigField("String", "BRIDGE_TOKEN", "\"$defaultBridgeToken\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        buildConfig = true
        viewBinding = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.json:json:20240303")

    // Samsung Health Data SDK is distributed separately.
    // Download the SDK from Samsung Developer and place the AAR/JAR inside app/libs.
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
}
