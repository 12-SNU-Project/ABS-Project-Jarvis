package com.jarvis.samsunghealthbridge

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.jarvis.samsunghealthbridge.databinding.ActivityMainBinding
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
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

        binding.backendUrlInput.setText(
            BridgePreferences.getBackendUrl(this),
        )
        binding.bridgeTokenInput.setText(
            BridgePreferences.getBridgeToken(this),
        )
        binding.autoSyncCheckbox.isChecked = BridgePreferences.isAutoSyncEnabled(this)

        binding.autoSyncCheckbox.setOnCheckedChangeListener { _, isChecked ->
            BridgePreferences.setAutoSyncEnabled(this, isChecked)
            if (isChecked) {
                SamsungHealthAutoSyncWorker.schedule(this)
                binding.statusText.text = "Status: auto sync enabled"
            } else {
                SamsungHealthAutoSyncWorker.cancel(this)
                binding.statusText.text = "Status: auto sync disabled"
            }
        }

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

                    BridgePreferences.saveBackendConfig(this@MainActivity, backendBaseUrl, bridgeToken)
                    if (binding.autoSyncCheckbox.isChecked) {
                        SamsungHealthAutoSyncWorker.schedule(this@MainActivity)
                    }

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
