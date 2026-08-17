package com.coffre.coffre

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypts the autofill session payload with an AES-256-GCM key
 * stored in the Android Keystore (hardware-backed when available).
 *
 * File on disk never contains plaintext credentials.
 */
object AutofillSessionStore {
    private const val KEY_ALIAS = "coffre_autofill_session_v1"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_BITS = 128
    private const val FILE_NAME = "autofill_session.enc"
    private const val LEGACY_PLAIN_NAME = "autofill_session.json"

    fun save(context: Context, plaintextJson: String) {
        ensureKey()
        val key = getKey()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv
        val ciphertext = cipher.doFinal(plaintextJson.toByteArray(Charsets.UTF_8))
        val envelope = JSONObject()
            .put("v", 1)
            .put("iv", Base64.encodeToString(iv, Base64.NO_WRAP))
            .put("ct", Base64.encodeToString(ciphertext, Base64.NO_WRAP))
        val file = sessionFile(context)
        val tmp = File(file.absolutePath + ".tmp")
        tmp.writeText(envelope.toString())
        if (file.exists()) file.delete()
        tmp.renameTo(file)
        // Remove any legacy plaintext cache from earlier builds.
        wipeLegacyPlain(context)
    }

    fun load(context: Context): JSONObject? {
        val file = sessionFile(context)
        if (!file.exists()) return null
        return try {
            ensureKey()
            val envelope = JSONObject(file.readText())
            val iv = Base64.decode(envelope.getString("iv"), Base64.NO_WRAP)
            val ct = Base64.decode(envelope.getString("ct"), Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            val clear = cipher.doFinal(ct).toString(Charsets.UTF_8)
            JSONObject(clear)
        } catch (_: Exception) {
            null
        }
    }

    fun clear(context: Context) {
        val file = sessionFile(context)
        if (file.exists()) {
            val wipe = ByteArray(file.length().coerceAtLeast(4096L).toInt()) { 0x5A }
            file.writeBytes(wipe)
            file.writeBytes(ByteArray(wipe.size) { 0xA5.toByte() })
            file.delete()
        }
        wipeLegacyPlain(context)
    }

    private fun wipeLegacyPlain(context: Context) {
        val legacy = File(context.filesDir, "coffre/$LEGACY_PLAIN_NAME")
        if (!legacy.exists()) return
        val wipe = ByteArray(legacy.length().coerceAtLeast(4096L).toInt()) { 0x3C }
        legacy.writeBytes(wipe)
        legacy.delete()
    }

    private fun sessionFile(context: Context): File {
        val dir = File(context.filesDir, "coffre")
        if (!dir.exists()) dir.mkdirs()
        return File(dir, FILE_NAME)
    }

    private fun ensureKey() {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (ks.containsAlias(KEY_ALIAS)) return
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(spec)
        keyGenerator.generateKey()
    }

    private fun getKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        return (ks.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry).secretKey
    }
}
