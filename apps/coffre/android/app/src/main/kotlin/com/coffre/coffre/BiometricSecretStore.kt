package com.coffre.coffre

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import java.nio.charset.StandardCharsets
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.security.KeyStore

/**
 * Small encrypted prefs for biometric secondary unlock secret.
 * AES-GCM key lives in Android Keystore.
 */
object BiometricSecretStore {
    private const val PREFS = "coffre_biometric_secrets"
    private const val KEY_ALIAS = "coffre_biometric_wrap_v1"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_BITS = 128

    fun write(context: Context, key: String, value: String) {
        ensureKey()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getKey())
        val iv = cipher.iv
        val ct = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        prefs(context).edit()
            .putString("$key.iv", Base64.encodeToString(iv, Base64.NO_WRAP))
            .putString("$key.ct", Base64.encodeToString(ct, Base64.NO_WRAP))
            .apply()
    }

    fun read(context: Context, key: String): String? {
        val prefs = prefs(context)
        val ivB64 = prefs.getString("$key.iv", null) ?: return null
        val ctB64 = prefs.getString("$key.ct", null) ?: return null
        return try {
            ensureKey()
            val iv = Base64.decode(ivB64, Base64.NO_WRAP)
            val ct = Base64.decode(ctB64, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            String(cipher.doFinal(ct), StandardCharsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    fun delete(context: Context, key: String) {
        prefs(context).edit()
            .remove("$key.iv")
            .remove("$key.ct")
            .apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun ensureKey() {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (ks.containsAlias(KEY_ALIAS)) return
        val kg = KeyGenerator.getInstance("AES", ANDROID_KEYSTORE)
        val spec = android.security.keystore.KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                android.security.keystore.KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        kg.init(spec)
        kg.generateKey()
    }

    private fun getKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        return (ks.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry).secretKey
    }
}
