package com.tajeerai.mobile.callerid

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.os.Build
import android.telecom.TelecomManager

class CallerIdRoleManager(private val context: Context) {
    fun isCallScreeningRoleHeld(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false

        val roleManager = context.getSystemService(RoleManager::class.java) ?: return false

        return roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    fun requestCallScreeningRole(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false

        val roleManager = context.getSystemService(RoleManager::class.java) ?: return false

        if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) return true

        if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) return false

        val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
        activity.startActivityForResult(intent, REQUEST_CODE)
        return true
    }

    companion object {
        const val REQUEST_CODE = 9101
    }
}
