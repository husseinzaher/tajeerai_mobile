package com.tajeerai.mobile.callerid

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.telephony.PhoneNumberUtils
import android.telephony.TelephonyManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Resolves a ringing number without the Flutter isolate.
 *
 * Reads the Drift database the app writes, so every column name and value
 * format here mirrors `customer_tables.dart` and
 * `caller_identity_cache_tables.dart`. Two conventions matter:
 *
 * - Drift stores every `DateTime` as ISO-8601 **text** (`build.yaml`,
 *   `store_date_time_values_as_text`). Reading one with `getLong` yields the
 *   year, and writing an epoch long corrupts the row for the Dart side.
 * - The cache key and the server query are the E.164 form, which the Dart
 *   side produces with a Saudi default region. `PhoneNormalizer` has to reach
 *   the same string for the same call.
 *
 * Nothing here throws to the caller: a missing database, a locked file or a
 * network error degrade to "unknown caller", never to no card.
 */
class CallerIdLookupEngine(private val context: Context) {
    private val prefs = CallerIdPreferences(context)
    private val executor = Executors.newCachedThreadPool()
    private val normalizer = PhoneNormalizer(context)

    fun normalize(rawPhone: String): NormalizedPhone? = normalizer.normalize(rawPhone)

    fun resolveImmediate(
        normalized: NormalizedPhone,
        settings: CallerIdPreferences,
    ): CallerIdentity {
        var identity: CallerIdentity? = null

        if (settings.useCachedData()) {
            identity = guard("cache") { readCache(normalized.e164) }
        }

        if (identity == null && settings.localLookupEnabled()) {
            identity = guard("local") { lookupLocalCustomer(normalized) }
        }

        val resolved = identity ?: CallerIdentity(
            phoneNumber = normalized.e164,
            displayName = null,
            source = "unknown",
        )

        return withLastNote(resolved)
    }

    fun resolveServerAsync(
        normalized: NormalizedPhone,
        settings: CallerIdPreferences,
        onResult: (CallerIdentity) -> Unit,
    ) {
        executor.execute {
            val remote = guard("server") { lookupServer(normalized.e164, settings) } ?: return@execute
            guard("cacheWrite") { cacheIdentity(remote) }
            onResult(withLastNote(remote))
        }
    }

    /**
     * The newest entry on the contact's own record, else the standing
     * description on the contact row. Resolved at display time from the local
     * database rather than cached, so the card never shows a note somebody has
     * since superseded.
     */
    private fun withLastNote(identity: CallerIdentity): CallerIdentity {
        val customerId = identity.customerId?.takeIf { it.isNotBlank() } ?: return identity
        val note = guard("note") { readLastNote(customerId) } ?: return identity

        return identity.copy(lastNote = note)
    }

    private fun openDatabase(writable: Boolean): SQLiteDatabase? {
        val dbPath = prefs.databasePath() ?: return null
        if (!File(dbPath).exists()) return null

        val flags = if (writable) SQLiteDatabase.OPEN_READWRITE else SQLiteDatabase.OPEN_READONLY

        return SQLiteDatabase.openDatabase(dbPath, null, flags)
    }

    private fun readCache(normalizedPhone: String): CallerIdentity? {
        val db = openDatabase(writable = false) ?: return null
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

                val expiresAt = IsoTimestamps.parse(cursor.getString(cursor.getColumnIndexOrThrow("expires_at")))
                if (expiresAt == null || expiresAt < System.currentTimeMillis()) return null

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
        if (normalized.suffix.isEmpty()) return null

        val db = openDatabase(writable = false) ?: return null
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

    private fun readLastNote(customerId: String): String? {
        val db = openDatabase(writable = false) ?: return null
        db.use { database ->
            database.rawQuery(
                """
                SELECT body FROM customer_notes
                WHERE customer_id = ?
                ORDER BY created_at DESC
                LIMIT 1
                """.trimIndent(),
                arrayOf(customerId),
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
                }
            }

            database.rawQuery(
                "SELECT notes FROM customers WHERE id = ? LIMIT 1",
                arrayOf(customerId),
            ).use { cursor ->
                if (!cursor.moveToFirst()) return null

                return cursor.getString(0)?.trim()?.takeIf { it.isNotEmpty() }
            }
        }
    }

    private fun lookupServer(
        normalizedPhone: String,
        settings: CallerIdPreferences,
    ): CallerIdentity? {
        val baseUrl = prefs.apiBaseUrl()?.trimEnd('/') ?: return null
        val token = prefs.accessToken() ?: return null

        // `+` in a query string decodes to a space; the backend strips
        // non-digits so it survived, but a server that stopped doing so would
        // silently match nothing.
        val encoded = URLEncoder.encode(normalizedPhone, "UTF-8")
        val connection = (URL("$baseUrl/v1/customers/lookup?phone=$encoded").openConnection()
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

            val order = data.optJSONObject("lastOrder")

            CallerIdentity(
                phoneNumber = normalizedPhone,
                displayName = name,
                businessName = data.optStringOrNull("typeName"),
                avatarUrl = data.optStringOrNull("photoUrl"),
                tags = decodeTags(data.optJSONArray("tags")),
                source = "server",
                customerId = id,
                address = data.optStringOrNull("address"),
                lastOrderReference = order?.optStringOrNull("reference"),
                lastOrderState = order?.optStringOrNull("state"),
                lastOrderCurrency = order?.optStringOrNull("currency"),
                lastOrderTotal = order?.optStringOrNull("grandTotal"),
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun cacheIdentity(identity: CallerIdentity) {
        val db = openDatabase(writable = true) ?: return
        db.use { database ->
            val now = System.currentTimeMillis()
            val expiresAt = now + TimeUnit.DAYS.toMillis(7)
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
                // Explicitly Any?: the values mix String? and String, and Kotlin
                // rejects reifying the inferred intersection. execSQL takes
                // Array<out Any?> anyway.
                arrayOf<Any?>(
                    identity.phoneNumber,
                    identity.displayName,
                    identity.businessName,
                    identity.avatarUrl,
                    identity.spamStatus ?: "unknown",
                    encodeTags(identity.tags),
                    identity.source ?: "unknown",
                    identity.customerId,
                    IsoTimestamps.format(now),
                    IsoTimestamps.format(expiresAt),
                ),
            )
        }
    }

    private fun <T> guard(stage: String, block: () -> T?): T? = try {
        block()
    } catch (error: Exception) {
        Log.w(TAG, "Caller lookup stage '$stage' failed", error)
        null
    }

    private fun decodeTags(raw: String?): List<String> {
        if (raw.isNullOrBlank() || raw == "[]") return emptyList()
        return try {
            decodeTags(JSONArray(raw))
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun decodeTags(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        return buildList {
            for (index in 0 until array.length()) {
                val tag = array.optString(index).trim()
                if (tag.isNotEmpty()) add(tag)
            }
        }
    }

    private fun encodeTags(tags: List<String>): String {
        val array = JSONArray()
        tags.forEach(array::put)
        return array.toString()
    }

    private fun JSONObject.optStringOrNull(key: String): String? {
        if (isNull(key)) return null
        return optString(key, "").takeIf { it.isNotBlank() }
    }

    companion object {
        private const val TAG = "CallerIdLookup"
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
    /** The newest note on the contact, resolved locally at display time. */
    val lastNote: String? = null,
    /**
     * From the server only - the phone keeps no orders. Where the last order
     * went, and the order itself: reference, state, currency and total.
     */
    val address: String? = null,
    val lastOrderReference: String? = null,
    val lastOrderState: String? = null,
    val lastOrderCurrency: String? = null,
    val lastOrderTotal: String? = null,
) {
    val isKnown: Boolean get() = !displayName.isNullOrBlank()
}

data class NormalizedPhone(
    val raw: String,
    val e164: String,
    val digits: String,
    val suffix: String,
)

/**
 * Drift's text timestamps: `DateTime.toIso8601String()`, which is
 * `yyyy-MM-ddTHH:mm:ss.ffffff` with a trailing `Z` when the value was UTC and
 * nothing when it was local. Both are accepted here; what is written is
 * always UTC with the `Z`, which `DateTime.parse` reads back exactly.
 */
internal object IsoTimestamps {
    fun format(epochMillis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date(epochMillis))
    }

    fun parse(value: String?): Long? {
        if (value.isNullOrBlank()) return null

        // An epoch written by an older build of this engine.
        value.toLongOrNull()?.let { return it }

        val utc = value.endsWith("Z")
        val head = value.removeSuffix("Z").take(19)
        if (head.length < 19) return null

        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        formatter.timeZone = if (utc) TimeZone.getTimeZone("UTC") else TimeZone.getDefault()

        return try {
            formatter.parse(head)?.time
        } catch (_: Exception) {
            null
        }
    }
}

/**
 * Mirrors `NormalizedPhone.parse` on the Dart side: E.164 through the
 * platform's libphonenumber with the device's region as the default, falling
 * back to Saudi Arabia, which is the default region the app uses.
 *
 * Without the parse, `0501234567` became `+0501234567`: a cache key the Dart
 * side never produces, and a server query whose digits match no stored row.
 */
class PhoneNormalizer(private val context: Context) {
    fun normalize(input: String): NormalizedPhone? {
        val trimmed = input.trim()
        if (trimmed.isEmpty() ||
            trimmed.equals("restricted", true) ||
            trimmed.equals("private", true) ||
            trimmed.equals("unknown", true) ||
            trimmed == "-1"
        ) {
            return null
        }

        val digits = trimmed.filter { it.isDigit() }
        if (digits.isEmpty()) return null

        // `00` is the international prefix on every network this app serves;
        // `+` is what libphonenumber understands everywhere.
        val candidate = if (trimmed.startsWith("00")) "+" + trimmed.substring(2) else trimmed

        val e164 = try {
            PhoneNumberUtils.formatNumberToE164(candidate, defaultRegion())
        } catch (_: Exception) {
            null
        } ?: "+$digits"

        val e164Digits = e164.filter { it.isDigit() }
        val suffix = if (e164Digits.length >= SIGNIFICANT_SUFFIX) {
            e164Digits.takeLast(SIGNIFICANT_SUFFIX)
        } else {
            e164Digits
        }

        return NormalizedPhone(
            raw = trimmed,
            e164 = e164,
            digits = e164Digits,
            suffix = suffix,
        )
    }

    private fun defaultRegion(): String {
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val fromNetwork = telephony?.networkCountryIso?.takeIf { it.length == 2 }
        val fromSim = telephony?.simCountryIso?.takeIf { it.length == 2 }

        return (fromNetwork ?: fromSim ?: DEFAULT_REGION).uppercase(Locale.US)
    }

    companion object {
        /** Matches `PhoneDigits.significantSuffix` on the Dart side. */
        private const val SIGNIFICANT_SUFFIX = 9
        private const val DEFAULT_REGION = "SA"
    }
}
