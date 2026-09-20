package com.tajeerai.mobile.callerid

import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.tajeerai.mobile.R

class CallerIdOverlayController(private val context: Context) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activeCallId: String? = null
    private var activeDirection: CallerIdCallScreeningService.CallDirection? = null
    private var overlayView: View? = null
    private var dismissRunnable: Runnable? = null

    fun show(
        callId: String,
        phoneNumber: String,
        direction: CallerIdCallScreeningService.CallDirection,
        identity: CallerIdentity?,
        settings: CallerIdPreferences,
    ) {
        mainHandler.post {
            if (!settings.showOverOtherApps()) return@post
            if (!Settings.canDrawOverlays(context)) return@post

            dismissInternal()

            activeCallId = callId
            activeDirection = direction
            val inflater = LayoutInflater.from(context)
            val view = inflater.inflate(R.layout.caller_id_overlay, null)

            bind(view, phoneNumber, direction, identity, settings)

            if (settings.dismissOnTap()) {
                view.setOnClickListener { dismissInternal() }
            }

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

            windowManager.addView(view, params)
            overlayView = view

            scheduleDismiss(settings.autoDismissSeconds())
        }
    }

    fun update(callId: String, identity: CallerIdentity) {
        mainHandler.post {
            if (activeCallId != callId) return@post
            val view = overlayView ?: return@post
            val settings = CallerIdPreferences(context)
            bind(
                view,
                identity.phoneNumber,
                activeDirection ?: CallerIdCallScreeningService.CallDirection.INCOMING,
                identity,
                settings,
            )
        }
    }

    fun dismissInternal() {
        dismissRunnable?.let(mainHandler::removeCallbacks)
        dismissRunnable = null

        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: IllegalArgumentException) {
            // Already removed.
        }
        overlayView = null
        activeCallId = null
        activeDirection = null
    }

    private fun scheduleDismiss(seconds: Int) {
        dismissRunnable?.let(mainHandler::removeCallbacks)
        dismissRunnable = Runnable { dismissInternal() }
        mainHandler.postDelayed(dismissRunnable!!, seconds * 1000L)
    }

    private fun bind(
        view: View,
        phoneNumber: String,
        direction: CallerIdCallScreeningService.CallDirection,
        identity: CallerIdentity?,
        settings: CallerIdPreferences,
    ) {
        val directionView = view.findViewById<TextView>(R.id.caller_direction)
        val nameView = view.findViewById<TextView>(R.id.caller_name)
        val phoneView = view.findViewById<TextView>(R.id.caller_phone)
        val businessView = view.findViewById<TextView>(R.id.caller_business)
        val tagsContainer = view.findViewById<LinearLayout>(R.id.caller_tags)
        val avatarView = view.findViewById<ImageView>(R.id.caller_avatar)

        directionView.text = when (direction) {
            CallerIdCallScreeningService.CallDirection.INCOMING -> "Incoming call"
            CallerIdCallScreeningService.CallDirection.OUTGOING -> "Outgoing call"
        }

        val displayName = identity?.displayName?.takeIf { it.isNotBlank() }
        nameView.visibility = if (settings.showCallerName()) View.VISIBLE else View.GONE
        nameView.text = displayName ?: phoneNumber

        phoneView.visibility =
            if (settings.showPhoneNumber() && displayName != null) View.VISIBLE else View.GONE
        phoneView.text = phoneNumber

        if (settings.showBusinessInfo() && !identity?.businessName.isNullOrBlank()) {
            businessView.visibility = View.VISIBLE
            businessView.text = identity?.businessName
        } else {
            businessView.visibility = View.GONE
        }

        avatarView.visibility = if (settings.showAvatar()) View.VISIBLE else View.GONE

        tagsContainer.removeAllViews()
        if (settings.showTags() && !identity?.tags.isNullOrEmpty()) {
            tagsContainer.visibility = View.VISIBLE
            identity?.tags?.forEach { tag ->
                val tagView = LayoutInflater.from(context)
                    .inflate(R.layout.caller_id_tag, tagsContainer, false) as TextView
                tagView.text = tag
                tagsContainer.addView(tagView)
            }
        } else {
            tagsContainer.visibility = View.GONE
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
}
