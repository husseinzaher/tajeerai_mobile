package com.tajeerai.mobile.callerid

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Follows one call from the ring to the hang-up, so the card can live as long
 * as the call does and say what happened when it is over.
 *
 * `CallScreeningService` says a call exists and nothing more; the phone's
 * call state is the only signal for "it was answered" and "it ended", and
 * reading it needs `READ_PHONE_STATE` - the SDK marks `onCallStateChanged`
 * with it. Without the grant the card falls back to its timer.
 *
 * Screening happens *before* the phone starts ringing, so the state at start
 * is usually IDLE. An IDLE that arrives before any RINGING or OFFHOOK is the
 * call not having started yet, not the call ending - the watcher waits for
 * the call to become real before it believes it has finished. A call that
 * never becomes real (blocked, dropped by the network) is closed by the
 * grace timer instead, so the card does not stand there forever.
 *
 * ## A call screened while the line is already busy
 *
 * Registering a listener makes the platform deliver the *current* state at
 * once. For the first call that is IDLE and harmless. For a second call - one
 * dialled or arriving while another is connected - it is OFFHOOK, and taking
 * that at face value timed the new call from the old call's connection and
 * then declared it over the moment the old one hung up. The card turned into
 * a summary while the phone was still ringing, and the real end found
 * `finished` already set, so nothing was written (owner, 2026-10-03).
 *
 * So the state at registration is remembered: a line that was **already busy**
 * means this call is not the only one on it, and the replayed OFFHOOK is the
 * other call's. It still counts as "a call exists", so the hang-up is
 * believed; what it does not do is claim this call was answered at a moment it
 * cannot know.
 *
 * What this still cannot do is time the second call properly - global call
 * state does not say *which* call connected, and only an `InCallService` would.
 * The note says the call happened rather than how long it ran, which is the
 * honest answer to a question this signal cannot settle.
 */
class CallerIdCallStateWatcher(
    private val context: Context,
    private val onEnded: (answered: Boolean, durationMs: Long) -> Unit,
) {
    private val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var callback: TelephonyCallback? = null

    @Suppress("DEPRECATION")
    private var legacyListener: PhoneStateListener? = null
    private var sawCall = false
    private var answeredAt: Long = 0L
    private var finished = false

    /** True when another call was already connected as this one was screened. */
    private var startedBusy = false

    private val graceTimeout = Runnable {
        if (!sawCall) finish(answered = false, durationMs = 0L)
    }

    fun start() {
        val manager = telephony ?: return

        /*
          Read before registering, because registering replays it and by then
          the two are indistinguishable.
        */
        startedBusy = try {
            @Suppress("DEPRECATION")
            manager.callState == TelephonyManager.CALL_STATE_OFFHOOK
        } catch (_: SecurityException) {
            false
        }
        if (startedBusy) {
            sawCall = true
            Log.i(TAG, "Screened while the line was already busy")
        }

        mainHandler.postDelayed(graceTimeout, GRACE_MS)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val modern = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) = handle(state)
                }
                callback = modern
                manager.registerTelephonyCallback(context.mainExecutor, modern)
            } else {
                @Suppress("DEPRECATION")
                val legacy = object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) = handle(state)
                }
                legacyListener = legacy
                @Suppress("DEPRECATION")
                manager.listen(legacy, PhoneStateListener.LISTEN_CALL_STATE)
            }
        } catch (error: SecurityException) {
            // The grant was revoked between the check and the register.
            Log.w(TAG, "Call state unavailable", error)
            stop()
        }
    }

    /** Whether this call had connected by now. Read when a newer call takes over. */
    fun wasAnswered(): Boolean = answeredAt != 0L

    /** How long it had been connected, or zero if it never was. */
    fun answeredDurationMs(): Long =
        if (answeredAt == 0L) 0L else System.currentTimeMillis() - answeredAt

    fun stop() {
        mainHandler.removeCallbacks(graceTimeout)
        val manager = telephony ?: return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                callback?.let(manager::unregisterTelephonyCallback)
            } else {
                @Suppress("DEPRECATION")
                legacyListener?.let { manager.listen(it, PhoneStateListener.LISTEN_NONE) }
            }
        } catch (_: Exception) {
            // Already unregistered, or the manager is gone with the process.
        }
        callback = null
        legacyListener = null
    }

    private fun handle(state: Int) {
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                sawCall = true
                mainHandler.removeCallbacks(graceTimeout)
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                sawCall = true
                mainHandler.removeCallbacks(graceTimeout)
                /*
                  The first OFFHOOK on a line that was already busy is the
                  *other* call's, replayed at registration. Anything after it
                  is a change, and a change is this call connecting.
                */
                if (startedBusy) {
                    startedBusy = false
                } else if (answeredAt == 0L) {
                    answeredAt = System.currentTimeMillis()
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (!sawCall) return
                val duration = if (answeredAt == 0L) 0L else System.currentTimeMillis() - answeredAt
                finish(answered = answeredAt != 0L, durationMs = duration)
            }
        }
    }

    private fun finish(answered: Boolean, durationMs: Long) {
        if (finished) return
        finished = true
        stop()
        onEnded(answered, durationMs)
    }

    companion object {
        private const val TAG = "CallerIdCallState"

        /** How long a screened call may take to start ringing before it is treated as gone. */
        private const val GRACE_MS = 20_000L

        fun isAvailable(context: Context): Boolean =
            context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
    }
}
