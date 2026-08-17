package com.coffre.coffre

import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

class CoffreAutofillService : AutofillService() {
    companion object {
        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.chrome.beta",
            "com.chrome.dev",
            "com.chrome.canary",
            "com.brave.browser",
            "org.mozilla.firefox",
            "org.mozilla.firefox_beta",
            "com.microsoft.emmx",
            "com.opera.browser",
            "com.sec.android.app.sbrowser",
        )
    }
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }

        val packageName = structure.activityComponent.packageName
        val fields = mutableListOf<ParsedField>()
        parseNode(structure.getWindowNodeAt(0).rootViewNode, fields)

        val usernameIds = fields.filter { it.isUsername }.map { it.id }
        val passwordIds = fields.filter { it.isPassword }.map { it.id }
        if (usernameIds.isEmpty() && passwordIds.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val cache = AutofillSessionStore.load(applicationContext)
        val unlocked = cache?.optBoolean("unlocked", false) == true
        val responseBuilder = FillResponse.Builder()

        if (!unlocked) {
            addInfoDataset(
                responseBuilder,
                usernameIds,
                passwordIds,
                "Coffre verrouillé — ouvrez l'app",
                "",
                "",
            )
            attachSaveInfo(responseBuilder, usernameIds, passwordIds)
            callback.onSuccess(responseBuilder.build())
            return
        }

        val entries = cache!!.optJSONArray("entries")
        if (entries == null) {
            attachSaveInfo(responseBuilder, usernameIds, passwordIds)
            callback.onSuccess(responseBuilder.build())
            return
        }

        val webDomain = findWebDomain(structure)
        val scored = mutableListOf<Pair<Int, org.json.JSONObject>>()
        for (i in 0 until entries.length()) {
            val entry = entries.getJSONObject(i)
            val score = matchScore(entry, packageName, webDomain)
            if (score > 0) scored.add(score to entry)
        }
        scored.sortByDescending { it.first }

        var added = 0
        val toShow = if (scored.isNotEmpty()) scored.map { it.second } else {
            (0 until entries.length()).map { entries.getJSONObject(it) }
        }
        for (entry in toShow) {
            val title = entry.optString("title", "Coffre")
            val username = entry.optString("username", "")
            val password = entry.optString("password", "")
            if (username.isEmpty() && password.isEmpty()) continue
            val domain = entry.optString("domain", "")
            val subtitle = buildString {
                append(if (username.isNotEmpty()) username else "Mot de passe")
                if (domain.isNotEmpty()) append(" · ").append(domain)
            }
            addEntryDataset(
                responseBuilder,
                usernameIds,
                passwordIds,
                title,
                subtitle,
                username,
                password,
            )
            added++
            if (added >= 12) break
        }

        if (added == 0) {
            addInfoDataset(
                responseBuilder,
                usernameIds,
                passwordIds,
                "Aucune entrée Coffre",
                "Ajoutez ce site dans Coffre",
                "",
            )
        }

        attachSaveInfo(responseBuilder, usernameIds, passwordIds)
        callback.onSuccess(responseBuilder.build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess()
            return
        }
        val packageName = structure.activityComponent.packageName
        val webDomain = findWebDomain(structure)
        val fields = mutableListOf<ParsedField>()
        parseNode(structure.getWindowNodeAt(0).rootViewNode, fields)

        var username = ""
        var password = ""
        for (field in fields) {
            val text = field.text ?: continue
            if (field.isPassword && password.isEmpty()) password = text
            if (field.isUsername && username.isEmpty()) username = text
        }
        if (username.isEmpty()) {
            for (field in fields) {
                val text = field.text ?: continue
                if (!field.isPassword && text.contains("@")) {
                    username = text
                    break
                }
            }
        }
        if (username.isEmpty() || password.isEmpty()) {
            callback.onSuccess()
            return
        }

        val cache = AutofillSessionStore.load(applicationContext)
        val entries = cache?.optJSONArray("entries")
        val action = classifyCaptured(
            entries,
            username,
            password,
            packageName,
            webDomain,
        )
        if (action == "unchanged") {
            callback.onSuccess()
            return
        }

        PendingAutofillSave.save(
            applicationContext,
            packageName,
            username,
            password,
            webDomain ?: "",
            action,
        )
        val launch = Intent(applicationContext, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("autofill_save", true)
        }
        startActivity(launch)
        callback.onSuccess()
    }

    private fun attachSaveInfo(
        builder: FillResponse.Builder,
        usernameIds: List<AutofillId>,
        passwordIds: List<AutofillId>,
    ) {
        val required = when {
            passwordIds.isNotEmpty() -> passwordIds.toTypedArray()
            usernameIds.isNotEmpty() -> usernameIds.toTypedArray()
            else -> return
        }
        val saveType = SaveInfo.SAVE_DATA_TYPE_PASSWORD or SaveInfo.SAVE_DATA_TYPE_USERNAME
        val saveBuilder = SaveInfo.Builder(saveType, required)
        if (passwordIds.isNotEmpty() && usernameIds.isNotEmpty()) {
            saveBuilder.setOptionalIds(usernameIds.toTypedArray())
        }
        if (Build.VERSION.SDK_INT >= 26) {
            saveBuilder.setFlags(SaveInfo.FLAG_SAVE_ON_ALL_VIEWS_INVISIBLE)
        }
        try {
            builder.setSaveInfo(saveBuilder.build())
        } catch (_: Exception) {
        }
    }

    private fun classifyCaptured(
        entries: org.json.JSONArray?,
        username: String,
        password: String,
        packageName: String,
        webDomain: String?,
    ): String {
        if (entries == null) return "create"
        val user = username.trim()
        val pkg = packageName.lowercase()
        val isBrowser = BROWSER_PACKAGES.contains(pkg)
        var sameUser: org.json.JSONObject? = null
        for (i in 0 until entries.length()) {
            val entry = entries.getJSONObject(i)
            if (entry.optString("username", "").trim().equals(user, ignoreCase = true).not()) continue
            if (!sameSite(entry, pkg, isBrowser, webDomain)) continue
            if (entry.optString("password", "") == password) return "unchanged"
            if (sameUser == null) sameUser = entry
        }
        return if (sameUser != null) "update" else "create"
    }

    private fun sameSite(
        entry: org.json.JSONObject,
        packageName: String,
        isBrowser: Boolean,
        webDomain: String?,
    ): Boolean {
        if (!isBrowser && packageName.isNotEmpty()) {
            val entryPkg = entry.optString("androidPackage", "")
            if (entryPkg.equals(packageName, ignoreCase = true)) return true
        }
        if (webDomain.isNullOrBlank()) return false
        val domain = entry.optString("domain", "")
        if (domain.isNotEmpty() && domainMatches(webDomain, domain)) return true
        val host = hostOf(entry.optString("url", ""))
        return host.isNotEmpty() && domainMatches(webDomain, host)
    }

    private fun matchScore(
        entry: org.json.JSONObject,
        packageName: String,
        webDomain: String?,
    ): Int {
        val entryPackage = entry.optString("androidPackage", "")
        val domain = entry.optString("domain", "")
        val url = entry.optString("url", "")
        val title = entry.optString("title", "")
        val username = entry.optString("username", "")
        val pkg = packageName.lowercase()
        var score = 0
        if (entryPackage.isNotEmpty() && entryPackage.equals(packageName, ignoreCase = true)) {
            score += 100
        }
        if (webDomain != null) {
            if (domain.isNotEmpty() && domainMatches(webDomain, domain)) score += 80
            if (url.isNotEmpty() && domainMatches(webDomain, hostOf(url))) score += 70
        }
        val pkgTail = pkg.substringAfterLast('.')
        val titleLower = title.lowercase()
        if (titleLower.isNotEmpty() && pkgTail.length >= 3 && titleLower.contains(pkgTail)) {
            score += 40
        }
        if (titleLower.isNotEmpty() && pkg.contains(titleLower.replace(" ", ""))) {
            score += 30
        }
        if (username.contains('@') && webDomain != null) {
            val userDomain = username.substringAfter('@').lowercase()
            if (domainMatches(webDomain, userDomain)) score += 20
        }
        return score
    }

    private fun hostOf(url: String): String {
        val cleaned = url.lowercase()
            .removePrefix("https://")
            .removePrefix("http://")
            .substringBefore('/')
            .substringBefore(':')
            .removePrefix("www.")
        return cleaned
    }

    private fun addInfoDataset(
        builder: FillResponse.Builder,
        usernameIds: List<AutofillId>,
        passwordIds: List<AutofillId>,
        title: String,
        subtitle: String,
        username: String,
    ) {
        val presentation = RemoteViews(applicationContext.packageName, android.R.layout.simple_list_item_2)
        presentation.setTextViewText(android.R.id.text1, title)
        presentation.setTextViewText(android.R.id.text2, subtitle)
        val dataset = Dataset.Builder(presentation)
        usernameIds.forEach { dataset.setValue(it, AutofillValue.forText(username)) }
        passwordIds.forEach { dataset.setValue(it, AutofillValue.forText("")) }
        try {
            builder.addDataset(dataset.build())
        } catch (_: Exception) {
        }
    }

    private fun addEntryDataset(
        builder: FillResponse.Builder,
        usernameIds: List<AutofillId>,
        passwordIds: List<AutofillId>,
        title: String,
        subtitle: String,
        username: String,
        password: String,
    ) {
        val presentation = RemoteViews(applicationContext.packageName, android.R.layout.simple_list_item_2)
        presentation.setTextViewText(android.R.id.text1, title)
        presentation.setTextViewText(android.R.id.text2, subtitle)
        val dataset = Dataset.Builder(presentation)
        usernameIds.forEach { dataset.setValue(it, AutofillValue.forText(username)) }
        if (password.isNotEmpty()) {
            passwordIds.forEach { dataset.setValue(it, AutofillValue.forText(password)) }
        }
        try {
            builder.addDataset(dataset.build())
        } catch (_: Exception) {
        }
    }

    private fun domainMatches(pageDomain: String, entryDomain: String): Boolean {
        val page = pageDomain.lowercase().removePrefix("www.")
        val entry = entryDomain.lowercase().removePrefix("www.")
        if (page.isEmpty() || entry.isEmpty()) return false
        return page == entry || page.endsWith(".$entry")
    }

    private fun findWebDomain(structure: AssistStructure): String? {
        fun walk(node: AssistStructure.ViewNode): String? {
            val web = node.webDomain
            if (!web.isNullOrBlank()) return web.lowercase().removePrefix("www.")
            for (i in 0 until node.childCount) {
                val found = walk(node.getChildAt(i))
                if (found != null) return found
            }
            return null
        }
        if (structure.windowNodeCount == 0) return null
        return walk(structure.getWindowNodeAt(0).rootViewNode)
    }

    private fun parseNode(node: AssistStructure.ViewNode, out: MutableList<ParsedField>) {
        val id = node.autofillId
        if (id != null) {
            val hints = (node.autofillHints ?: emptyArray()).map { it.lowercase() }
            val className = node.className?.lowercase() ?: ""
            val inputType = node.inputType
            val text = node.text?.toString()
                ?: node.autofillValue?.takeIf { it.isText }?.textValue?.toString()
            val isPassword = hints.any { it.contains("password") } ||
                className.contains("password") ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD) != 0 ||
                (inputType and android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD) != 0
            val nameHints = hints.any {
                it.contains("given-name") || it.contains("family-name") || it.contains("person-name")
            }
            val isUsername = !nameHints && (
                hints.any {
                    it.contains("username") || it.contains("email") || it.contains("login")
                } || (inputType and android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS) != 0
                    || (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS) != 0
            )
            if (isPassword || isUsername) {
                out.add(
                    ParsedField(
                        id = id,
                        isUsername = isUsername && !isPassword,
                        isPassword = isPassword,
                        text = text,
                    ),
                )
            }
        }
        for (i in 0 until node.childCount) {
            parseNode(node.getChildAt(i), out)
        }
    }

    private data class ParsedField(
        val id: AutofillId,
        val isUsername: Boolean,
        val isPassword: Boolean,
        val text: String? = null,
    )
}
