package com.tajeerai.mobile.callerid

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Telecom hands every call here while this app holds the call-screening role.
 *
 * The response goes back first and unconditionally, so a failure anywhere
 * below can delay a ring but never block one. Everything after it is best
 * effort: an exception on the worker thread would otherwise reach the
 * thread's default handler and take the whole process down with it, which
 * read to the member as "the card never appears".
 */
class CallerIdCallScreeningService : CallScreeningService() {
    private val lookupEngine by lazy { CallerIdLookupEngine(applicationContext) }

    /**
     * The process's one card, not this instance's.
     *
     * Telecom binds this service once per call, so a controller owned by the
     * instance meant the second call could not take the card - or the
     * telephony watcher behind it - away from the first. See
     * `CallerIdOverlayController`'s own note.
     */
    private val overlay by lazy { CallerIdOverlayController.of(applicationContext) }

    override fun onScreenCall(callDetails: Call.Details) {
        val builder = CallScreeningService.CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setSkipCallLog(false).setSkipNotification(false)
        }

        respondToCall(callDetails, builder.build())

        try {
            screen(callDetails)
        } catch (error: Exception) {
            Log.w(TAG, "Caller ID screening failed", error)
        }
    }

    private fun screen(callDetails: Call.Details) {
        val settings = CallerIdPreferences(applicationContext)
        if (!settings.isEnabled() || !settings.cardEnabled()) {
            Log.i(TAG, "Call screened; caller ID is off in settings")
            return
        }

        val handle = callDetails.handle?.schemeSpecificPart?.trim().orEmpty()
        if (handle.isEmpty()) {
            Log.i(TAG, "Call screened; no handle (private number)")
            return
        }

        val direction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            when (callDetails.callDirection) {
                Call.Details.DIRECTION_INCOMING -> CallDirection.INCOMING
                Call.Details.DIRECTION_OUTGOING -> CallDirection.OUTGOING
                else -> return
            }
        } else {
            // The screening role does not exist below Q, so this service is
            // never bound there; the branch only keeps the compiler honest.
            CallDirection.INCOMING
        }

        if (direction == CallDirection.INCOMING && !settings.shouldShowIncoming()) return
        if (direction == CallDirection.OUTGOING && !settings.shouldShowOutgoing()) return

        val normalized = lookupEngine.normalize(handle)
        if (normalized == null) {
            Log.i(TAG, "Call screened; handle could not be normalised")
            return
        }
        val callId = UUID.randomUUID().toString()
        // The number itself stays out of the log; its length and the region
        // result are enough to tell a normalisation problem from a lookup one.
        Log.i(TAG, "Screening $direction call, handle length=${handle.length}, e164 length=${normalized.e164.length}")

        executor.execute {
            try {
                val immediate = lookupEngine.resolveImmediate(normalized, settings)
                val known = immediate.isKnown
                Log.i(TAG, "Resolved locally: known=$known source=${immediate.source}")

                if (settings.shouldShowOnlyUnknown() && known) return@execute
                if (!settings.shouldShowContacts() && known) return@execute

                overlay.show(
                    callId = callId,
                    phoneNumber = normalized.e164,
                    direction = direction,
                    identity = immediate,
                    settings = settings,
                )

                // Asked even for a caller the phone already knows: the name
                // is local, but the last order and the address live only on
                // the server, and the card fills them in when the answer lands.
                if (settings.serverLookupEnabled()) {
                    lookupEngine.resolveServerAsync(normalized, settings) { updated ->
                        overlay.update(callId, updated)
                    }
                }
            } catch (error: Exception) {
                Log.w(TAG, "Caller ID resolution failed", error)
            }
        }
    }

    enum class CallDirection {
        INCOMING,
        OUTGOING,
    }

    private companion object {
        const val TAG = "CallerIdScreening"

        /**
         * One worker for the process. It was created per service instance,
         * which leaked a thread for every call screened - the instance is
         * unbound the moment `respondToCall` returns, long before the lookup
         * it started comes back.
         */
        val executor: java.util.concurrent.ExecutorService = Executors.newSingleThreadExecutor()
    }
}
