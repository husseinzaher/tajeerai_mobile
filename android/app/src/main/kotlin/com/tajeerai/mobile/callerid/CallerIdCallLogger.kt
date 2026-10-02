package com.tajeerai.mobile.callerid

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import com.tajeerai.mobile.R
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Writes a finished call onto the contact's record on the server, as a note.
 *
 * A note rather than a call log of its own: the customer timeline is where a
 * merchant already reads what happened with this person, the endpoint and
 * its permissions exist, and the web's follow-ups panel reads the same rows.
 * The same line is also written as an internal note on the contact's most
 * recent conversation, when the phone has one, so the thread itself says
 * "called, answered, three minutes" where the team reads it. A caller the
 * workspace does not know has no record to write to, so nothing is sent for
 * them - the summary card offers to add them instead.
 *
 * Best effort and off the main thread. A failed write is logged and dropped;
 * there is no retry queue because a note about a call that ended an hour ago
 * is not worth a background job, and the next call will write its own.
 */
class CallerIdCallLogger(private val context: Context) {
    private val prefs = CallerIdPreferences(context)
    private val executor = Executors.newSingleThreadExecutor()

    fun log(
        ui: Context,
        identity: CallerIdentity?,
        phoneNumber: String,
        direction: CallerIdCallScreeningService.CallDirection,
        answered: Boolean,
        durationLabel: String,
    ) {
        val customerId = identity?.customerId?.takeIf { it.isNotBlank() } ?: return
        val baseUrl = prefs.apiBaseUrl()?.trimEnd('/') ?: return
        val token = prefs.accessToken() ?: return

        val incoming = direction == CallerIdCallScreeningService.CallDirection.INCOMING
        val body = when {
            incoming && answered -> ui.getString(R.string.caller_id_log_incoming_answered, phoneNumber, durationLabel)
            incoming -> ui.getString(R.string.caller_id_log_incoming_missed, phoneNumber)
            answered -> ui.getString(R.string.caller_id_log_outgoing_answered, phoneNumber, durationLabel)
            else -> ui.getString(R.string.caller_id_log_outgoing_unanswered, phoneNumber)
        }

        executor.execute {
            post("$baseUrl/v1/customers/$customerId/notes", token, body, "customer record")
            latestConversationFor(customerId)?.let { conversationId ->
                post("$baseUrl/v1/conversations/$conversationId/notes", token, body, "conversation")
            }
        }
    }

    /**
     * The contact's most recent thread, read from the database the app keeps
     * (`conversation_tables.dart`). Local rather than asked of the server: the
     * list endpoint has no filter by contact, and the phone already holds the
     * answer.
     */
    private fun latestConversationFor(customerId: String): String? {
        val dbPath = prefs.databasePath() ?: return null
        if (!File(dbPath).exists()) return null

        return try {
            SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery(
                    """
                    SELECT id FROM conversations
                    WHERE customer_id = ? AND is_archived = 0
                    ORDER BY last_message_at DESC
                    LIMIT 1
                    """.trimIndent(),
                    arrayOf(customerId),
                ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not read the contact's conversations", error)
            null
        }
    }

    private fun post(url: String, token: String, body: String, target: String) {
        run {
            val connection = try {
                (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = TIMEOUT_MS
                    readTimeout = TIMEOUT_MS
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Authorization", "Bearer $token")
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    setRequestProperty("Accept", "application/json")
                }
            } catch (error: Exception) {
                Log.w(TAG, "Call log request could not be built", error)
                return@run
            }

            try {
                connection.outputStream.use { stream ->
                    stream.write(JSONObject().put("body", body).toString().toByteArray(Charsets.UTF_8))
                }
                val code = connection.responseCode
                if (code in 200..299) {
                    Log.i(TAG, "Call logged to the $target")
                } else {
                    Log.w(TAG, "Call log to the $target refused with HTTP $code")
                }
            } catch (error: Exception) {
                Log.w(TAG, "Call log to the $target did not reach the server", error)
            } finally {
                connection.disconnect()
            }
        }
    }

    private companion object {
        const val TAG = "CallerIdCallLog"
        const val TIMEOUT_MS = 5_000
    }
}
