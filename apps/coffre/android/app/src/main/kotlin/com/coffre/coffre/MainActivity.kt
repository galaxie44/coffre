package com.coffre.coffre

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingCsvResult: MethodChannel.Result? = null
    private val csvPicker = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        val reply = pendingCsvResult
        pendingCsvResult = null
        if (reply == null) return@registerForActivityResult
        if (uri == null) {
            reply.success(null)
            return@registerForActivityResult
        }
        try {
            val text = contentResolver.openInputStream(uri)
                ?.bufferedReader(Charsets.UTF_8)
                ?.use { it.readText() }
            reply.success(text)
        } catch (e: Exception) {
            reply.error("read_failed", e.message, null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.coffre/autofill")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAutofillSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("unavailable", e2.message, null)
                            }
                        }
                    }
                    "writeSession" -> {
                        try {
                            val json = call.argument<String>("json")
                                ?: throw IllegalArgumentException("json manquant")
                            AutofillSessionStore.save(applicationContext, json)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("write_failed", e.message, null)
                        }
                    }
                    "clearSession" -> {
                        try {
                            AutofillSessionStore.clear(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("clear_failed", e.message, null)
                        }
                    }
                    "getPendingSave" -> {
                        try {
                            val pending = PendingAutofillSave.load(applicationContext)
                            if (pending == null) {
                                result.success(null)
                            } else {
                                result.success(
                                    mapOf(
                                        "packageName" to pending.optString("packageName"),
                                        "username" to pending.optString("username"),
                                        "password" to pending.optString("password"),
                                        "webDomain" to pending.optString("webDomain"),
                                        "action" to pending.optString("action"),
                                    ),
                                )
                            }
                        } catch (e: Exception) {
                            result.error("pending_failed", e.message, null)
                        }
                    }
                    "clearPendingSave" -> {
                        try {
                            PendingAutofillSave.clear(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("clear_pending_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.coffre/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickCsv" -> {
                        if (pendingCsvResult != null) {
                            result.error("busy", "Un fichier est déjà en cours de sélection", null)
                            return@setMethodCallHandler
                        }
                        pendingCsvResult = result
                        csvPicker.launch(arrayOf("text/*", "text/comma-separated-values", "*/*"))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.coffre/danger")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestUninstall" -> {
                        try {
                            val intent = Intent(Intent.ACTION_DELETE).apply {
                                data = Uri.parse("package:$packageName")
                                putExtra(Intent.EXTRA_RETURN_RESULT, true)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("uninstall_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.coffre/secrets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "write" -> {
                        try {
                            val key = call.argument<String>("key")
                                ?: throw IllegalArgumentException("key")
                            val value = call.argument<String>("value")
                                ?: throw IllegalArgumentException("value")
                            BiometricSecretStore.write(applicationContext, key, value)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("write_failed", e.message, null)
                        }
                    }
                    "read" -> {
                        try {
                            val key = call.argument<String>("key")
                                ?: throw IllegalArgumentException("key")
                            result.success(BiometricSecretStore.read(applicationContext, key))
                        } catch (e: Exception) {
                            result.error("read_failed", e.message, null)
                        }
                    }
                    "delete" -> {
                        try {
                            val key = call.argument<String>("key")
                                ?: throw IllegalArgumentException("key")
                            BiometricSecretStore.delete(applicationContext, key)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("delete_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
