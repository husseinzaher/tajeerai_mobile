package com.tajeerai.mobile.callerid

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.tajeerai.mobile.R
import java.net.HttpURLConnection
import java.net.URL
import java.text.NumberFormat
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.abs

/**
 * The caller card: one window, drawn over whatever is on screen while a phone
 * rings, and kept until the call is over.
 *
 * ## Its lifetime is the call's
 *
 * With `READ_PHONE_STATE` the card stays for the whole call and then turns
 * into a summary - who it was, whether it was answered, for how long - with
 * the two things a merchant does next: open (or save) the contact, or call
 * back. Without the permission it falls back to the timer the settings name.
 *
 * ## It reads the app's locale, not the phone's
 *
 * Strings and direction come from the locale the member chose in the app,
 * passed down with the runtime config. A merchant running an Arabic workspace
 * on an English phone gets an Arabic card, which is what the rest of the app
 * already does.
 *
 * ## There is exactly one of these in the process
 *
 * It used to be a `by lazy` field on `CallerIdCallScreeningService`, and
 * Telecom binds that service once per call - so the second call got a *second*
 * controller, which knew nothing about the first. `show()` opens by calling
 * `dismissInternal()` precisely so a new call takes the card over from the
 * previous one, and on a fresh instance that call tears down nothing: the
 * first call's card could still be on screen with its own telephony watcher
 * registered, and the second call's summary and its note to the thread were
 * lost behind it (owner, 2026-10-03).
 *
 * Worse, whether that happened at all depended on whether Android chose to
 * reuse the service instance, which is not a thing this code may rely on. One
 * instance, reached through [of], makes "the newest call owns the card" true
 * by construction.
 */
class CallerIdOverlayController private constructor(private val appContext: Context) {
    private val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val imageExecutor = Executors.newSingleThreadExecutor()

    private var activeCallId: String? = null
    private var activeDirection: CallerIdCallScreeningService.CallDirection? = null
    private var activePhone: String? = null
    private var activeIdentity: CallerIdentity? = null
    private var overlayView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var dismissRunnable: Runnable? = null
    private var callWatcher: CallerIdCallStateWatcher? = null
    private var summaryShown = false
    private val callLogger = CallerIdCallLogger(appContext)

    /** The avatar URL currently on screen, so a stale load never replaces a newer one. */
    private var shownAvatarUrl: String? = null

    fun show(
        callId: String,
        phoneNumber: String,
        direction: CallerIdCallScreeningService.CallDirection,
        identity: CallerIdentity?,
        settings: CallerIdPreferences,
    ) {
        mainHandler.post {
            if (!settings.showOverOtherApps()) {
                Log.i(TAG, "Card suppressed: showOverOtherApps is off")
                return@post
            }
            if (!Settings.canDrawOverlays(appContext)) {
                Log.w(TAG, "Card suppressed: overlay permission not granted")
                return@post
            }

            /*
              The call this card is being taken from, if it was still live.

              `dismissInternal` stops its watcher, so without this the previous
              call would never reach `showSummary` and its note would never be
              written - a second call starting would quietly erase the first
              one's record. The card itself is gone either way; what is kept is
              the line on the contact and in the thread, which is the part a
              merchant reads tomorrow.
            */
            closePreviousCall(settings)
            dismissInternal()

            activeCallId = callId
            activeDirection = direction
            activePhone = phoneNumber
            activeIdentity = identity
            summaryShown = false

            val ui = localized(settings.locale())
            val view = LayoutInflater.from(ui).inflate(R.layout.caller_id_overlay, null)
            view.layoutDirection = if (isRtl(settings.locale())) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = gravityFor(settings.cardPosition())
                y = verticalOffset(settings.cardPosition())
            }
            layoutParams = params

            bind(view, ui, callId, phoneNumber, direction, identity, settings)
            wireGestures(view, ui, settings)

            try {
                windowManager.addView(view, params)
            } catch (error: Exception) {
                // The permission was revoked between the check and the add, or
                // the window token is gone. A missing card beats a dead process.
                Log.w(TAG, "Could not attach the caller card", error)
                return@post
            }
            overlayView = view
            Log.i(TAG, "Caller card shown")

            if (CallerIdCallStateWatcher.isAvailable(appContext)) {
                val watcher = CallerIdCallStateWatcher(appContext) { answered, durationMs ->
                    mainHandler.post { showSummary(callId, ui, answered, durationMs, settings) }
                }
                callWatcher = watcher
                watcher.start()
                // A safety net, not the lifetime: a call the watcher loses track
                // of must still not leave a card on screen for an hour - unless
                // the member chose a card that only they close.
                scheduleDismiss(if (settings.autoDismissSeconds() <= 0) 0 else MAX_CARD_SECONDS)
            } else {
                scheduleDismiss(settings.autoDismissSeconds())
            }
        }
    }

    fun update(callId: String, identity: CallerIdentity) {
        mainHandler.post {
            if (activeCallId != callId) return@post
            val view = overlayView ?: return@post
            val settings = CallerIdPreferences(appContext)
            activeIdentity = identity
            bind(
                view,
                localized(settings.locale()),
                callId,
                identity.phoneNumber,
                activeDirection ?: CallerIdCallScreeningService.CallDirection.INCOMING,
                identity,
                settings,
            )
            if (summaryShown) bindActions(view, localized(settings.locale()))
        }
    }

    /**
     * Writes the record for a call that is losing the card to a newer one.
     *
     * Only when there was one, it was still being watched, and it had not
     * already said its piece. Nothing is drawn: the card is about to be
     * replaced, and a summary nobody can see is not worth the frame.
     *
     * `answered` is taken from the watcher rather than guessed, and a call
     * taken over mid-ring is reported as what it was - unanswered.
     */
    private fun closePreviousCall(settings: CallerIdPreferences) {
        val watcher = callWatcher ?: return
        val phone = activePhone ?: return
        if (summaryShown) return

        val answered = watcher.wasAnswered()
        val duration = formatDuration(watcher.answeredDurationMs())

        Log.i(TAG, "A new call took the card; recording the previous one")

        if (settings.logCallsToServer()) {
            callLogger.log(
                localized(settings.locale()),
                activeIdentity,
                phone,
                activeDirection ?: CallerIdCallScreeningService.CallDirection.INCOMING,
                answered,
                duration,
            )
        }
    }

    fun dismissInternal() {
        dismissRunnable?.let(mainHandler::removeCallbacks)
        dismissRunnable = null
        callWatcher?.stop()
        callWatcher = null

        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: IllegalArgumentException) {
            // Already removed.
        }
        overlayView = null
        layoutParams = null
        activeCallId = null
        activeDirection = null
        activePhone = null
        activeIdentity = null
        shownAvatarUrl = null
        summaryShown = false
    }

    // -- the summary -------------------------------------------------------

    private fun showSummary(
        callId: String,
        ui: Context,
        answered: Boolean,
        durationMs: Long,
        settings: CallerIdPreferences,
    ) {
        if (activeCallId != callId) return
        val view = overlayView ?: return
        summaryShown = true

        val direction = activeDirection ?: CallerIdCallScreeningService.CallDirection.INCOMING
        val incoming = direction == CallerIdCallScreeningService.CallDirection.INCOMING
        val duration = formatDuration(durationMs)

        // The header line steps aside for the status line below the identity,
        // which is where the eye lands after a call: what happened, with its
        // glyph, the way every dialler draws it.
        view.findViewById<TextView>(R.id.caller_direction).text =
            ui.getString(R.string.caller_id_call_ended)

        val status = view.findViewById<View>(R.id.caller_status)
        val statusIcon = view.findViewById<ImageView>(R.id.caller_status_icon)
        val statusText = view.findViewById<TextView>(R.id.caller_status_text)
        status.visibility = View.VISIBLE
        when {
            answered && incoming -> {
                statusIcon.setImageResource(R.drawable.ic_caller_id_call_received)
                statusText.text = "${ui.getString(R.string.caller_id_answered)} · ${ui.getString(R.string.caller_id_duration, duration)}"
                statusText.setTextColor(ui.getColor(R.color.caller_id_text_secondary))
            }
            answered -> {
                statusIcon.setImageResource(R.drawable.ic_caller_id_call_made)
                statusText.text = ui.getString(R.string.caller_id_duration, duration)
                statusText.setTextColor(ui.getColor(R.color.caller_id_text_secondary))
            }
            incoming -> {
                statusIcon.setImageResource(R.drawable.ic_caller_id_call_missed)
                statusText.text = ui.getString(R.string.caller_id_missed_call)
                statusText.setTextColor(ui.getColor(R.color.caller_id_danger))
            }
            else -> {
                statusIcon.setImageResource(R.drawable.ic_caller_id_call_made)
                statusText.text = ui.getString(R.string.caller_id_call_ended)
                statusText.setTextColor(ui.getColor(R.color.caller_id_text_secondary))
            }
        }

        bindActions(view, ui)
        Log.i(TAG, "Call ended; summary shown (answered=$answered)")

        if (settings.logCallsToServer()) {
            activePhone?.let { phone ->
                callLogger.log(ui, activeIdentity, phone, direction, answered, duration)
            }
        }

        scheduleDismiss(if (settings.autoDismissSeconds() <= 0) 0 else SUMMARY_SECONDS)
    }

    private fun bindActions(view: View, ui: Context) {
        val actions = view.findViewById<LinearLayout>(R.id.caller_actions)
        val callBack = view.findViewById<View>(R.id.caller_action_call)
        val message = view.findViewById<View>(R.id.caller_action_message)
        val customer = view.findViewById<ImageButton>(R.id.caller_action_customer)
        val identity = activeIdentity
        val phone = activePhone ?: return

        actions.visibility = View.VISIBLE

        callBack.setOnClickListener {
            launch(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
            dismissInternal()
        }

        // WhatsApp, because that is where this product's merchants talk to
        // their customers; the digits alone are what wa.me accepts.
        message.setOnClickListener {
            launch(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/${phone.filter { it.isDigit() }}")))
            dismissInternal()
        }

        val customerId = identity?.customerId?.takeIf { it.isNotBlank() }
        customer.contentDescription = ui.getString(
            if (customerId != null) R.string.caller_id_open_customer else R.string.caller_id_add_customer,
        )
        customer.setOnClickListener {
            openInApp(if (customerId != null) customerLink(customerId) else newCustomerLink(phone))
            dismissInternal()
        }
    }

    // -- binding -------------------------------------------------------------

    private fun bind(
        view: View,
        ui: Context,
        callId: String,
        phoneNumber: String,
        direction: CallerIdCallScreeningService.CallDirection,
        identity: CallerIdentity?,
        settings: CallerIdPreferences,
    ) {
        val directionView = view.findViewById<TextView>(R.id.caller_direction)
        val nameView = view.findViewById<TextView>(R.id.caller_name)
        val phoneView = view.findViewById<TextView>(R.id.caller_phone)
        val businessView = view.findViewById<TextView>(R.id.caller_business)
        val initialView = view.findViewById<TextView>(R.id.caller_avatar_initial)
        val avatarView = view.findViewById<ImageView>(R.id.caller_avatar)
        val factsView = view.findViewById<LinearLayout>(R.id.caller_facts)
        val tagsContainer = view.findViewById<LinearLayout>(R.id.caller_tags)

        if (!summaryShown) {
            directionView.setText(
                when (direction) {
                    CallerIdCallScreeningService.CallDirection.INCOMING -> R.string.caller_id_incoming
                    CallerIdCallScreeningService.CallDirection.OUTGOING -> R.string.caller_id_outgoing
                },
            )
        }

        val displayName = identity?.displayName?.trim()?.takeIf { it.isNotEmpty() }
        val shownPhone = identity?.phoneNumber?.takeIf { it.isNotBlank() } ?: phoneNumber

        // The name line always carries *something*: with no name the member
        // still has to know who is ringing, and "unknown" is the honest word.
        nameView.visibility = if (settings.showCallerName() || displayName == null) View.VISIBLE else View.GONE
        nameView.text = displayName ?: ui.getString(R.string.caller_id_unknown_caller)

        phoneView.visibility = if (settings.showPhoneNumber() || displayName == null) View.VISIBLE else View.GONE
        phoneView.text = shownPhone

        val business = identity?.businessName?.trim()?.takeIf { it.isNotEmpty() }
        if (settings.showBusinessInfo() && business != null) {
            businessView.visibility = View.VISIBLE
            businessView.text = business
        } else {
            businessView.visibility = View.GONE
        }

        initialView.text = displayName?.firstOrNull()?.uppercaseChar()?.toString() ?: "#"
        bindAvatar(initialView, avatarView, callId, identity?.avatarUrl, settings)

        // Facts: the order first - it is the one with money on it - then
        // where they are, then what somebody last wrote down.
        val orderLine = identity?.let { orderLine(ui, it) }
        val shownOrder = bindFact(view, R.id.caller_fact_order, ui.getString(R.string.caller_id_last_order), orderLine)
        val shownAddress = bindFact(view, R.id.caller_fact_address, ui.getString(R.string.caller_id_address), identity?.address)
        val shownNote = bindFact(view, R.id.caller_fact_note, ui.getString(R.string.caller_id_last_note), identity?.lastNote)
        factsView.visibility = if (shownOrder || shownAddress || shownNote) View.VISIBLE else View.GONE

        tagsContainer.removeAllViews()
        val tags = identity?.tags.orEmpty().filter { it.isNotBlank() }
        if (settings.showTags() && tags.isNotEmpty()) {
            tagsContainer.visibility = View.VISIBLE
            // A single horizontal row: past a few chips the rest would run off
            // the card, so the row is capped rather than clipped.
            tags.take(MAX_TAGS).forEach { tag ->
                val tagView = LayoutInflater.from(ui)
                    .inflate(R.layout.caller_id_tag, tagsContainer, false) as TextView
                tagView.text = tag
                tagsContainer.addView(tagView)
            }
        } else {
            tagsContainer.visibility = View.GONE
        }
    }

    private fun bindFact(view: View, rowId: Int, label: String, value: String?): Boolean {
        val row = view.findViewById<View>(rowId)
        val text = value?.trim()?.takeIf { it.isNotEmpty() }
        if (text == null) {
            row.visibility = View.GONE
            return false
        }
        row.visibility = View.VISIBLE
        row.findViewById<TextView>(R.id.caller_fact_label).text = label
        row.findViewById<TextView>(R.id.caller_fact_value).text = text
        return true
    }

    /** "#1042 · Delivered · 450.00 SAR", or null when there is no order. */
    private fun orderLine(ui: Context, identity: CallerIdentity): String? {
        val reference = identity.lastOrderReference?.takeIf { it.isNotBlank() } ?: return null
        val state = identity.lastOrderState.orEmpty()
        val stateId = ui.resources.getIdentifier(
            "caller_id_order_state_$state",
            "string",
            ui.packageName,
        )
        val stateLabel = if (stateId != 0) ui.getString(stateId) else state
        val amount = formatAmount(identity.lastOrderTotal, identity.lastOrderCurrency)

        return ui.getString(R.string.caller_id_order_line, reference, stateLabel, amount)
    }

    private fun bindAvatar(
        initialView: TextView,
        avatarView: ImageView,
        callId: String,
        avatarUrl: String?,
        settings: CallerIdPreferences,
    ) {
        val parent = initialView.parent as View
        if (!settings.showAvatar()) {
            parent.visibility = View.GONE
            return
        }
        parent.visibility = View.VISIBLE

        val url = avatarUrl?.trim()?.takeIf { it.startsWith("https://") || it.startsWith("http://") }
        if (url == null || url == shownAvatarUrl) return

        // The initial stays until a real picture arrives; a failed load leaves
        // it there rather than blanking the slot.
        imageExecutor.execute {
            val bitmap = loadAvatar(url) ?: return@execute
            mainHandler.post {
                if (activeCallId != callId) return@post
                shownAvatarUrl = url
                avatarView.setImageDrawable(RoundDrawable(avatarView.resources, bitmap))
                avatarView.visibility = View.VISIBLE
                initialView.visibility = View.INVISIBLE
            }
        }
    }

    // -- gestures ------------------------------------------------------------

    private fun wireGestures(view: View, ui: Context, settings: CallerIdPreferences) {
        val card = view.findViewById<View>(R.id.caller_overlay_root)
        view.findViewById<ImageButton>(R.id.caller_close).setOnClickListener { dismissInternal() }

        // A tap opens the contact, if there is one to open. The card is a
        // window of its own, so this is the only way from it into the app.
        card.setOnClickListener {
            val customerId = activeIdentity?.customerId?.takeIf { it.isNotBlank() }
            if (customerId != null) {
                openInApp(customerLink(customerId))
                dismissInternal()
            } else if (settings.dismissOnTap()) {
                dismissInternal()
            }
        }

        // Drag to move. Vertical only: the card is as wide as the screen, and
        // a reader moving it is getting it off the answer buttons.
        val slop = ViewConfiguration.get(ui).scaledTouchSlop
        var downY = 0f
        var startY = 0
        var moved = false
        card.setOnTouchListener { v, event ->
            val params = layoutParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downY = event.rawY
                    startY = params.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = event.rawY - downY
                    if (abs(dy) > slop) moved = true
                    if (moved) {
                        // With BOTTOM gravity a positive y pushes the window *up*.
                        val sign = if (params.gravity and Gravity.BOTTOM == Gravity.BOTTOM) -1 else 1
                        params.y = startY + (sign * dy).toInt()
                        try {
                            windowManager.updateViewLayout(view, params)
                        } catch (_: IllegalArgumentException) {
                            // The window is already gone.
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) v.performClick()
                    true
                }
                MotionEvent.ACTION_CANCEL -> true
                else -> false
            }
        }
    }

    // -- helpers -------------------------------------------------------------

    /**
     * Zero or less means never: the member asked for a card that stays until
     * they close it, and the X is always there. A positive number is seconds.
     */
    private fun scheduleDismiss(seconds: Int) {
        dismissRunnable?.let(mainHandler::removeCallbacks)
        dismissRunnable = null
        if (seconds <= 0) return

        dismissRunnable = Runnable { dismissInternal() }
        mainHandler.postDelayed(dismissRunnable!!, seconds * 1000L)
    }

    private fun customerLink(customerId: String): Uri =
        Uri.parse("tajeerai://customers/${Uri.encode(customerId)}")

    private fun newCustomerLink(phone: String): Uri =
        Uri.parse("tajeerai://customers/new?phone=${Uri.encode(phone)}")

    private fun openInApp(link: Uri) {
        launch(Intent(Intent.ACTION_VIEW, link).setPackage(appContext.packageName))
    }

    private fun launch(intent: Intent) {
        try {
            appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (error: ActivityNotFoundException) {
            Log.w(TAG, "Nothing to open ${intent.data}", error)
        }
    }

    private fun localized(localeCode: String?): Context {
        val code = localeCode?.takeIf { it.isNotBlank() } ?: return appContext
        val locale = Locale.forLanguageTag(code)
        val config = Configuration(appContext.resources.configuration)
        config.setLocale(locale)
        config.setLayoutDirection(locale)
        return appContext.createConfigurationContext(config)
    }

    private fun isRtl(localeCode: String?): Boolean = localeCode?.startsWith("ar") == true

    private fun formatDuration(durationMs: Long): String {
        val totalSeconds = TimeUnit.MILLISECONDS.toSeconds(durationMs)
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format(Locale.US, "%02d:%02d", minutes, seconds)
    }

    /**
     * "450.00 SAR". Latin digits in every language - the member reads this
     * figure out loud - and the ISO code rather than a symbol, because the
     * symbol for the Saudi riyal is not in every font yet.
     */
    private fun formatAmount(total: String?, currency: String?): String {
        val code = currency?.trim().orEmpty()
        val value = total?.toBigDecimalOrNull() ?: return listOf(total.orEmpty(), code).filter { it.isNotBlank() }.joinToString(" ")
        val formatter = NumberFormat.getNumberInstance(Locale.US).apply {
            minimumFractionDigits = 2
            maximumFractionDigits = 2
        }
        return listOf(formatter.format(value), code).filter { it.isNotBlank() }.joinToString(" ")
    }

    private fun loadAvatar(url: String): Bitmap? {
        val connection = try {
            (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = AVATAR_TIMEOUT_MS
                readTimeout = AVATAR_TIMEOUT_MS
                instanceFollowRedirects = true
            }
        } catch (error: Exception) {
            Log.w(TAG, "Caller avatar URL is not usable", error)
            return null
        }

        return try {
            if (connection.responseCode !in 200..299) return null

            val bytes = connection.inputStream.use { it.readBytes() }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)

            // A profile photo can be a camera original; decode it at roughly
            // the size it will be drawn.
            val target = (AVATAR_SIZE_DP * appContext.resources.displayMetrics.density).toInt()
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= target && bounds.outHeight / (sample * 2) >= target) {
                sample *= 2
            }

            BitmapFactory.decodeByteArray(
                bytes,
                0,
                bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sample },
            )
        } catch (error: Exception) {
            Log.w(TAG, "Caller avatar did not load", error)
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun gravityFor(position: String): Int = when (position) {
        "center" -> Gravity.CENTER_HORIZONTAL or Gravity.CENTER_VERTICAL
        "bottom" -> Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM
        else -> Gravity.CENTER_HORIZONTAL or Gravity.TOP
    }

    private fun verticalOffset(position: String): Int = when (position) {
        "bottom" -> 96
        "center" -> 0
        else -> 96
    }

    /** A bitmap clipped to a circle, without pulling in a drawable library for one view. */
    private class RoundDrawable(
        resources: android.content.res.Resources,
        bitmap: Bitmap,
    ) : BitmapDrawable(resources, bitmap) {
        private val path = android.graphics.Path()

        override fun onBoundsChange(bounds: android.graphics.Rect) {
            super.onBoundsChange(bounds)
            path.reset()
            path.addOval(android.graphics.RectF(bounds), android.graphics.Path.Direction.CW)
        }

        override fun draw(canvas: android.graphics.Canvas) {
            val saved = canvas.save()
            canvas.clipPath(path)
            super.draw(canvas)
            canvas.restoreToCount(saved)
        }
    }

    companion object {
        @Volatile
        private var instance: CallerIdOverlayController? = null

        /**
         * The one controller, created on first use.
         *
         * Keyed on nothing: there is one phone, one screen and one card. The
         * application context is held, never an Activity or a Service, so the
         * instance outliving either of those is correct rather than a leak.
         */
        fun of(context: Context): CallerIdOverlayController =
            instance ?: synchronized(this) {
                instance ?: CallerIdOverlayController(context.applicationContext).also {
                    instance = it
                }
            }

        private const val TAG = "CallerIdOverlay"
        /** Two at most: a third chip is where the row stops reading as a label and starts reading as a list. */
        private const val MAX_TAGS = 2
        private const val AVATAR_SIZE_DP = 56
        private const val AVATAR_TIMEOUT_MS = 1500

        /** How long the summary stays once the call has ended. */
        private const val SUMMARY_SECONDS = 45

        /** The longest a live card may stand, whatever the watcher says. */
        private const val MAX_CARD_SECONDS = 60 * 60
    }
}
