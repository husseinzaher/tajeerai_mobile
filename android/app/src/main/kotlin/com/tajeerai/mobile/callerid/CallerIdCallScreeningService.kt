package com.tajeerai.mobile.callerid

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import java.util.UUID
import java.util.concurrent.Executors

class CallerIdCallScreeningService : CallScreeningService() {
    private val executor = Executors.newSingleThreadExecutor()
    private val lookupEngine by lazy { CallerIdLookupEngine(applicationContext) }
    private val overlay by lazy { CallerIdOverlayController(applicationContext) }

    override fun onScreenCall(callDetails: Call.Details) {
        val builder = CallScreeningService.CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setSkipCallLog(false).setSkipNotification(false)
        }

        val response = builder.build()

        respondToCall(callDetails, response)

        val settings = CallerIdPreferences(applicationContext)
        if (!settings.isEnabled() || !settings.cardEnabled()) return

        val handle = callDetails.handle?.schemeSpecificPart?.trim().orEmpty()
        if (handle.isEmpty()) return

        val direction = when (callDetails.callDirection) {
            Call.Details.DIRECTION_INCOMING -> CallDirection.INCOMING
            Call.Details.DIRECTION_OUTGOING -> CallDirection.OUTGOING
            else -> return
        }

        if (direction == CallDirection.INCOMING && !settings.shouldShowIncoming()) return
        if (direction == CallDirection.OUTGOING && !settings.shouldShowOutgoing()) return

        val callId = UUID.randomUUID().toString()

        executor.execute {
            val immediate = lookupEngine.resolveImmediate(handle, settings)
            val known = immediate?.displayName?.isNotBlank() == true

            if (settings.shouldShowOnlyUnknown() && known) return@execute
            if (!settings.shouldShowContacts() && known) return@execute

            overlay.show(
                callId = callId,
                phoneNumber = handle,
                direction = direction,
                identity = immediate,
                settings = settings,
            )

            if (settings.serverLookupEnabled()) {
                lookupEngine.resolveServerAsync(handle, settings) { updated ->
                    overlay.update(callId, updated)
                }
            }
        }
    }

    enum class CallDirection {
        INCOMING,
        OUTGOING,
    }
}
