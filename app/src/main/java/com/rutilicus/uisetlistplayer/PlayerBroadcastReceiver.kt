package com.rutilicus.uisetlistplayer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PlayerBroadcastReceiver: BroadcastReceiver() {
    companion object {
        val BROADCAST_ACTION = "com.rutilicus.uisetlistplayer.PLAYER_BROADCAST"
        val KEY_NOTIFICATION = "key_notification"
    }

    private val methodMap = mutableMapOf<String, () -> Unit>()

    override fun onReceive(context: Context?, intent: Intent?) {
        val extras = intent?.extras
        if (extras != null) {
            methodMap[extras.getString(KEY_NOTIFICATION)]?.invoke()
        }
    }

    fun setNotificationMethod(key: String, method: () -> Unit) {
        methodMap[key] = method
    }
}
