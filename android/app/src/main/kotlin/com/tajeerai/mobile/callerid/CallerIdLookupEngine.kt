package com.tajeerai.mobile.callerid

import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class CallerIdLookupEngine(private val context: android.content.Context) {
    private val prefs = CallerIdPreferences(context)
    private val executor = Executors.newCachedThreadPool()

    fun resolveImmediate(
        rawPhone: String,
        settings: CallerIdPreferences,
    ): CallerIdentity? {
        val normalized = PhoneNormalizer.normalize(rawPhone) ?: return null

        if (settings.useCachedData()) {
            readCache(normalized.e164)?.let { return it }
        }

        if (settings.localLookupEnabled()) {
            lookupLocalCustomer(normalized)?.let { return it }
        }

        return CallerIdentity(
            phoneNumber = normalized.e164,
            displayName = null,
            source = "unknown",
        )
    }

    fun resolveServerAsync(
        rawPhone: String,
        settings: CallerIdPreferences,
        onResult: (CallerIdentity) -> Unit,
    ) {
        executor.execute {
            val normalized = PhoneNormalizer.normalize(rawPhone) ?: return@execute
            val remote = lookupServer(normalized.e164, settings) ?: return@execute
            cacheIdentity(remote)
            onResult(remote)
        }
    }

    private fun readCache(normalizedPhone: String): CallerIdentity? {
        val dbPath = prefs.databasePath() ?: return null
        val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
        db.use { database ->
            database.rawQuery(
                """
                SELECT normalized_phone, display_name, business_name, avatar_url,
                       spam_status, tags_json, source, customer_id, expires_at
                FROM caller_identity_caches
                WHERE normalized_phone = ?
                LIMIT 1
                """.trimIndent(),
                arrayOf(normalizedPhone),
            ).use { cursor ->
                if (!cursor.moveToFirst()) return null
                val expiresAt = cursor.getLong(cursor.getColumnIndexOrThrow("expires_at"))
                if (expiresAt < System.currentTimeMillis()) return null

                return CallerIdentity(
                    phoneNumber = cursor.getString(cursor.getColumnIndexOrThrow("normalized_phone")),
                    displayName = cursor.getString(cursor.getColumnIndexOrThrow("display_name")),
                    businessName = cursor.getString(cursor.getColumnIndexOrThrow("business_name")),
                    avatarUrl = cursor.getString(cursor.getColumnIndexOrThrow("avatar_url")),
                    spamStatus = cursor.getString(cursor.getColumnIndexOrThrow("spam_status")),
                    tags = decodeTags(cursor.getString(cursor.getColumnIndexOrThrow("tags_json"))),
                    source = cursor.getString(cursor.getColumnIndexOrThrow("source")),
                    customerId = cursor.getString(cursor.getColumnIndexOrThrow("customer_id")),
                )
            }
        }
    }

    private fun lookupLocalCustomer(normalized: NormalizedPhone): CallerIdentity? {
        val dbPath = prefs.databasePath() ?: return null
        val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
        db.use { database ->
            database.rawQuery(
                """
                SELECT id, name, phone, photo_url, type_name, tags
                FROM customers
                WHERE phone_suffix = ?
                ORDER BY updated_at DESC
                LIMIT 1
                """.trimIndent(),
                arrayOf(normalized.suffix),
            ).use { cursor ->
                if (!cursor.moveToFirst()) return null

                return CallerIdentity(
                    phoneNumber = normalized.e164,
                    displayName = cursor.getString(cursor.getColumnIndexOrThrow("name")),
                    businessName = cursor.getString(cursor.getColumnIndexOrThrow("type_name")),
                    avatarUrl = cursor.getString(cursor.getColumnIndexOrThrow("photo_url")),
                    tags = decodeTags(cursor.getString(cursor.getColumnIndexOrThrow("tags"))),
                    source = "localCustomer",
                    customerId = cursor.getString(cursor.getColumnIndexOrThrow("id")),
                )
            }
        }
    }

    private fun lookupServer(
        normalizedPhone: String,
        settings: CallerIdPreferences,
    ): CallerIdentity? {
        val baseUrl = prefs.apiBaseUrl()?.trimEnd('/') ?: return null
        val token = prefs.accessToken() ?: return null

        val connection = (URL("$baseUrl/v1/customers/lookup?phone=$normalizedPhone").openConnection()
            as HttpURLConnection).apply {
            connectTimeout = SERVER_TIMEOUT_MS.toInt()
            readTimeout = SERVER_TIMEOUT_MS.toInt()
            requestMethod = "GET"
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
        }

        return try {
            if (connection.responseCode !in 200..299) return null

            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)
            val data = json.optJSONObject("data") ?: return null
            val id = data.optString("id", "")
            val name = data.optString("name", "")

            if (id.isBlank() || name.isBlank()) return null

            CallerIdentity(
                phoneNumber = normalizedPhone,
                displayName = name,
                businessName = data.optString("typeName", null),
                avatarUrl = data.optString("photoUrl", null),
                tags = decodeTags(data.optJSONArray("tags")),
                source = "server",
                customerId = id,
            )
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun cacheIdentity(identity: CallerIdentity) {
        val dbPath = prefs.databasePath() ?: return
        val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READWRITE)
        db.use { database ->
            val expiresAt = System.currentTimeMillis() + TimeUnit.DAYS.toMillis(7)
            database.execSQL(
                """
                INSERT INTO caller_identity_caches(
                  normalized_phone, display_name, business_name, avatar_url,
                  spam_status, tags_json, source, customer_id, fetched_at, expires_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(normalized_phone) DO UPDATE SET
                  display_name = excluded.display_name,
                  business_name = excluded.business_name,
                  avatar_url = excluded.avatar_url,
                  spam_status = excluded.spam_status,
                  tags_json = excluded.tags_json,
                  source = excluded.source,
                  customer_id = excluded.customer_id,
                  fetched_at = excluded.fetched_at,
                  expires_at = excluded.expires_at
                """.trimIndent(),
                arrayOf(
                    identity.phoneNumber,
                    identity.displayName,
                    identity.businessName,
                    identity.avatarUrl,
                    identity.spamStatus ?: "unknown",
                    encodeTags(identity.tags),
                    identity.source ?: "unknown",
                    identity.customerId,
                    System.currentTimeMillis(),
                    expiresAt,
                ),
            )
        }
    }

    private fun decodeTags(raw: String?): List<String> {
        if (raw.isNullOrBlank() || raw == "[]") return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    add(array.optString(index))
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun decodeTags(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        return buildList {
            for (index in 0 until array.length()) {
                add(array.optString(index))
            }
        }
    }

    private fun encodeTags(tags: List<String>): String {
        val array = JSONArray()
        tags.forEach(array::put)
        return array.toString()
    }

    companion object {
        private const val SERVER_TIMEOUT_MS = 1200L
    }
}

data class CallerIdentity(
    val phoneNumber: String,
    val displayName: String?,
    val businessName: String? = null,
    val avatarUrl: String? = null,
    val spamStatus: String? = "unknown",
    val tags: List<String> = emptyList(),
    val source: String? = "unknown",
    val customerId: String? = null,
)

data class NormalizedPhone(
    val raw: String,
    val e164: String,
    val digits: String,
    val suffix: String,
)

object PhoneNormalizer {
    fun normalize(input: String): NormalizedPhone? {
        val trimmed = input.trim()
        if (trimmed.isEmpty() || trimmed.equals("restricted", true) || trimmed.equals("private", true)) {
            return null
        }

        val digits = trimmed.filter { it.isDigit() }
        if (digits.isEmpty()) return null

        val suffix = if (digits.length >= 9) digits.takeLast(9) else digits
        val e164 = if (trimmed.startsWith("+")) trimmed else "+$digits"

        return NormalizedPhone(
            raw = trimmed,
            e164 = e164,
            digits = digits,
            suffix = suffix,
        )
    }
}
