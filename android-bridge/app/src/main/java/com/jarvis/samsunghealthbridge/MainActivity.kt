package com.jarvis.samsunghealthbridge

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.jarvis.samsunghealthbridge.databinding.ActivityMainBinding
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    companion object {
        private const val PREFS_NAME = "samsung_health_bridge_prefs"
        private const val KEY_BACKEND_URL = "backend_url"
        private const val KEY_BRIDGE_TOKEN = "bridge_token"
    }

    private lateinit var binding: ActivityMainBinding
    private lateinit var bridge: SamsungHealthBridge

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        bridge = SamsungHealthBridge(
            activity = this,
            statusSink = { message -> binding.statusText.text = "Status: $message" },
        )

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        binding.backendUrlInput.setText(
            prefs.getString(KEY_BACKEND_URL, BuildConfig.BACKEND_BASE_URL),
        )
        binding.bridgeTokenInput.setText(
            prefs.getString(KEY_BRIDGE_TOKEN, BuildConfig.BRIDGE_TOKEN),
        )

        binding.connectButton.setOnClickListener {
            bridge.connect()
        }

        binding.permissionButton.setOnClickListener {
            lifecycleScope.launch {
                runCatching {
                    bridge.requestSleepPermission()
                }.onFailure { error ->
                    binding.statusText.text = "Status: permission failed\n${error.message}"
                    Toast.makeText(this@MainActivity, error.message, Toast.LENGTH_LONG).show()
                }
            }
        }

        binding.uploadButton.setOnClickListener {
            lifecycleScope.launch {
                runCatching {
                    val backendBaseUrl = binding.backendUrlInput.text.toString().trim()
                    val bridgeToken = binding.bridgeTokenInput.text.toString().trim()
                    require(backendBaseUrl.isNotBlank()) { "Enter the backend URL first." }
                    require(bridgeToken.isNotBlank()) { "Enter the bridge token first." }

                    prefs.edit()
                        .putString(KEY_BACKEND_URL, backendBaseUrl)
                        .putString(KEY_BRIDGE_TOKEN, bridgeToken)
                        .apply()

                    bridge.readRecentSleepAndUpload(
                        backendBaseUrl = backendBaseUrl,
                        bridgeToken = bridgeToken,
                        rangeDays = 7,
                    )
                }.onSuccess { result ->
                    binding.statusText.text = "Status: upload success\n$result"
                }.onFailure { error ->
                    binding.statusText.text = "Status: upload failed\n${error.message}"
                    Toast.makeText(this@MainActivity, error.message, Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    override fun onDestroy() {
        bridge.disconnect()
        super.onDestroy()
    }
}
