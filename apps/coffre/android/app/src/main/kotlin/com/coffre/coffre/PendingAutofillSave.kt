package com.coffre.coffre

import android.content.Context
import org.json.JSONObject
import java.io.File

object PendingAutofillSave {
    private const val FILE = "pending_autofill_save.json"

    fun save(
        context: Context,
        packageName: String,
        username: String,
        password: String,
        webDomain: String = "",
        action: String = "create",
    ) {
        val json = JSONObject()
            .put("packageName", packageName)
            .put("username", username)
            .put("password", password)
            .put("webDomain", webDomain)
            .put("action", action)
            .put("savedAt", System.currentTimeMillis())
        file(context).writeText(json.toString())
    }

    fun load(context: Context): JSONObject? {
        val f = file(context)
        if (!f.exists()) return null
        return try {
            JSONObject(f.readText())
        } catch (_: Exception) {
            null
        }
    }

    fun clear(context: Context) {
        file(context).delete()
    }

    private fun file(context: Context): File {
        return File(context.filesDir, FILE)
    }
}
