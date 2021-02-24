package com.rutilicus.uisetlistplayer

import android.webkit.JavascriptInterface

class JSInterface(val getCurrentTimeListener: (Int) -> Unit,
                  val getPlayerStateListener: (Int) -> Unit) {
    @JavascriptInterface
    fun getCurrentTime(time: Int) {
        getCurrentTimeListener(time)
    }

    @JavascriptInterface
    fun getPlayerState(state: Int) {
        getPlayerStateListener(state)
    }
}
