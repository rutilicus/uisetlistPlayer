package com.rutilicus.uisetlistplayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.ImageButton
import android.widget.ListView
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.android.volley.toolbox.JsonArrayRequest
import com.android.volley.toolbox.Volley
import kotlin.random.Random
import androidx.media.app.NotificationCompat.MediaStyle

class MainFragment : Fragment() {
    private val SERVER_PATH = "https://uisetlist.herokuapp.com/"
    private val API_PATH = "api/song"
    private val PREV_SONG_THRES = 5
    private val NOTIFICATION_ID = 5151

    private val NOTIFICATION_KEY_PREV = "notify_prev"
    private val NOTIFICATION_KEY_NEXT = "notify_next"
    private val NOTIFICATION_KEY_PLAY = "notify_play"

    private val NOTIFICATION_REQUEST_PREV = 100
    private val NOTIFICATION_REQUEST_PLAY = NOTIFICATION_REQUEST_PREV + 1
    private val NOTIFICATION_REQUEST_NEXT = NOTIFICATION_REQUEST_PLAY + 1

    enum class RepeatState(val image: Int) {
        OFF(R.drawable.baseline_repeat_24),
        ON(R.drawable.baseline_repeat_on_24),
        SHUFFLE(R.drawable.baseline_shuffle_on_24);

        companion object {
            fun nextState(state: RepeatState): RepeatState {
                return values().let {
                    val nextState = (state.ordinal + 1) % it.size
                    it[nextState]
                }
            }
        }
    }

    var songArray = arrayOf<Song>()
    var currentSongIndex: Int? = null
    var currentTime = 0
    var repeatState = RepeatState.OFF

    lateinit var audioManager: AudioManager

    private lateinit var textViewSong: TextView
    private var webView: WebView? = null
    private var buttonPrev: ImageButton? = null
    private var buttonPlay: ImageButton? = null
    private var buttonNext: ImageButton? = null
    private var buttonRepeat: ImageButton? = null

    private val controlButtonArray = arrayOf(buttonPrev, buttonPlay, buttonNext, buttonRepeat)

    private var audioFocusRequest: AudioFocusRequest? = null

    private var manager: NotificationManagerCompat? = null
    private var builder: NotificationCompat.Builder? = null
    private var playPendingIntent: PendingIntent? = null

    private val handler = Handler()
    private val runnable = object: Runnable {
        override fun run() {
            val songIndex = currentSongIndex ?: -1
            if (songIndex != -1) {
                // 非同期処理のため、曲の遷移処理はgetCurrentTime関数で実行する
                webView?.loadUrl("javascript:getCurrentTime()")
                webView?.loadUrl("javascript:getPlayerState()")
            }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_main, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // AudioManager設定
        audioManager = context?.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // WebView設定
        webView = view.findViewById(R.id.webview_player)
        webView?.settings?.javaScriptEnabled = true
        webView?.settings?.mediaPlaybackRequiresUserGesture = false

        webView?.addJavascriptInterface(JSInterface(::getCurrentTime, ::getPlayerState), "android")

        webView?.loadUrl("file:///android_asset/player.html")

        // 各種View取得
        textViewSong = view.findViewById(R.id.text_play_song)
        buttonPrev = view.findViewById(R.id.button_skip_prev)
        buttonPlay = view.findViewById(R.id.button_play)
        buttonNext = view.findViewById(R.id.button_skip_next)
        buttonRepeat = view.findViewById(R.id.button_repeat)
        setButtonEnable()

        buttonPrev?.setOnClickListener {
            seekPrev()
        }

        buttonNext?.setOnClickListener {
            seekNext()
        }

        buttonPlay?.setOnClickListener {
            playStop()
        }

        buttonRepeat?.setOnClickListener {
            repeatState = RepeatState.nextState(repeatState)
            buttonRepeat?.setImageResource(repeatState.image)
        }

        // HTTP通信で歌一覧取得
        val queue = Volley.newRequestQueue(context)
        val url = SERVER_PATH + API_PATH

        val request = JsonArrayRequest(
            url,
            { response ->
                val songList = mutableListOf<Song>()
                for (i in 0 until response.length()) {
                    val songData = response.getJSONObject(i)
                    songList.add(Song(
                        songName = songData.getString("songName"),
                        startTime = songData.getInt("time"),
                        endTime = songData.getInt("endTime"),
                        artist = songData.getString("artist"),
                        movieId = songData.getJSONObject("movie").getString("movieId"),
                        movieName = songData.getJSONObject("movie").getString("name")
                    ))
                }

                if (context != null) {
                    val adapter = SongArrayAdapter(context!!)
                    songArray = songList.toTypedArray()
                    adapter.songArray = songArray
                    val listView = view.findViewById<ListView>(R.id.listview_song)
                    listView.adapter = adapter
                    listView.setOnItemClickListener { parent, view, position, id ->
                        requestAudioFocus()
                        webView?.loadUrl("javascript:loadVideoById('${songArray[position].movieId}',${songArray[position].startTime})")

                        seekSong(-1, position)
                    }

                    setButtonEnable()
                }
            },
            {
                Toast.makeText(context, R.string.error_text, Toast.LENGTH_LONG).show()
            }
        )

        queue.add(request)

        handler.post(runnable)
    }

    override fun onResume() {
        super.onResume()

        if (context != null) {
            with(NotificationManagerCompat.from(context!!)) {
                cancel(NOTIFICATION_ID)
                builder = null
            }
        }
    }

    override fun onPause() {
        super.onPause()

        // 音声停止
        pauseVideo()
        abandonAudioFocus()

        // 通知領域に再生コントロールを出す
        if (currentSongIndex != null) {
            if (context != null) {
                val broadcastReceiver = PlayerBroadcastReceiver()
                val intentFilter = IntentFilter(PlayerBroadcastReceiver.BROADCAST_ACTION)

                broadcastReceiver.setNotificationMethod(NOTIFICATION_KEY_PREV, ::seekPrev)
                broadcastReceiver.setNotificationMethod(NOTIFICATION_KEY_NEXT, ::seekNext)
                broadcastReceiver.setNotificationMethod(NOTIFICATION_KEY_PLAY, ::playStop)

                val prevPendingIntent = with(Intent()) {
                    this.action = PlayerBroadcastReceiver.BROADCAST_ACTION
                    this.putExtra(PlayerBroadcastReceiver.KEY_NOTIFICATION, NOTIFICATION_KEY_PREV)
                    PendingIntent.getBroadcast(
                        context,
                        NOTIFICATION_REQUEST_PREV,
                        this,
                        PendingIntent.FLAG_UPDATE_CURRENT
                    )
                }
                playPendingIntent = with(Intent()) {
                    this.action = PlayerBroadcastReceiver.BROADCAST_ACTION
                    this.putExtra(PlayerBroadcastReceiver.KEY_NOTIFICATION, NOTIFICATION_KEY_PLAY)
                    PendingIntent.getBroadcast(
                        context,
                        NOTIFICATION_REQUEST_PLAY,
                        this,
                        PendingIntent.FLAG_UPDATE_CURRENT
                    )
                }
                val nextPendingIntent = with(Intent()) {
                    this.action = PlayerBroadcastReceiver.BROADCAST_ACTION
                    this.putExtra(PlayerBroadcastReceiver.KEY_NOTIFICATION, NOTIFICATION_KEY_NEXT)
                    PendingIntent.getBroadcast(
                        context,
                        NOTIFICATION_REQUEST_NEXT,
                        this,
                        PendingIntent.FLAG_UPDATE_CURRENT
                    )
                }

                context!!.registerReceiver(broadcastReceiver, intentFilter)
                with(NotificationManagerCompat.from(context!!)) {
                    builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val notificationChannel = NotificationChannel(
                            getString(R.string.notification_channel_id),
                            getString(R.string.notification_channel_name),
                            NotificationManager.IMPORTANCE_LOW
                        )
                        this.createNotificationChannel(notificationChannel)
                        NotificationCompat.Builder(context!!, notificationChannel.id)
                    } else {
                        NotificationCompat.Builder(context!!)
                    }
                    val notification = builder!!
                        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                        .setSmallIcon(R.drawable.ic_stat_play)
                        .setContentTitle(songArray[currentSongIndex!!].songName)
                        .setAutoCancel(false)
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .addAction(R.drawable.baseline_skip_previous_24, "Previous", prevPendingIntent)
                        .addAction(R.drawable.baseline_play_arrow_24, "Play", playPendingIntent)
                        .addAction(R.drawable.baseline_skip_next_24, "Next", nextPendingIntent)
                        .setStyle(MediaStyle().setShowActionsInCompactView(1))
                        .build()
                    notification!!.flags = Notification.FLAG_NO_CLEAR
                    notify(NOTIFICATION_ID, notification)

                    manager = this
                }
            }
        }
    }

    private fun seekSong(songIndex: Int, nextSongIndex: Int) {
        if (songIndex != -1 && songArray[songIndex].movieId == songArray[nextSongIndex].movieId) {
            webView?.post {
                webView?.loadUrl("javascript:seekTo(${songArray[nextSongIndex].startTime})")
            }
        } else {
            webView?.post {
                webView?.loadUrl("javascript:loadVideoById('${songArray[nextSongIndex].movieId}',${songArray[nextSongIndex].startTime})")
            }
        }
        currentSongIndex = nextSongIndex
        State.isPlaying = true
    }

    private fun setButtonEnable() {
        controlButtonArray.forEach {
            it?.isClickable = songArray.isNotEmpty()
        }
    }

    private fun getCurrentTime(time: Int) {
        currentTime = time

        // Javascript側の処理が非同期のため、ここで曲の遷移処理を実施
        currentSongIndex?.apply {
            if (currentTime >= songArray[this].endTime) {
                when(repeatState) {
                    RepeatState.OFF -> {
                        val nextSongIndex = if (this + 1 >= songArray.size) 0 else this + 1
                        seekSong(this, nextSongIndex)
                    }
                    RepeatState.ON -> {
                        seekSong(this, this)
                    }
                    RepeatState.SHUFFLE -> {
                        seekSong(this, Random.nextInt(songArray.size))
                    }
                }
            }
            activity?.runOnUiThread {
                textViewSong.text = songArray[currentSongIndex!!].songName
                buttonPlay?.setImageResource(
                    if (State.isPlaying) R.drawable.baseline_pause_24 else R.drawable.baseline_play_arrow_24
                )
            }
            if (builder != null && manager != null) {
                builder!!.setContentTitle(songArray[currentSongIndex!!].songName)
                builder!!.mActions[1] =
                    NotificationCompat.Action(
                        if (State.isPlaying) R.drawable.baseline_pause_24 else R.drawable.baseline_play_arrow_24,
                        if (State.isPlaying) "Pause" else "Play",
                        playPendingIntent
                    )
                manager!!.notify(
                    NOTIFICATION_ID,
                    builder!!.build().apply { flags = Notification.FLAG_NO_CLEAR }
                )
            }
        }
    }

    private fun getPlayerState(state: Int) {
        // state: 1は再生中
        State.isPlaying = state == 1
    }

    private fun playVideo() {
        webView?.loadUrl("javascript:playVideo()")

        State.isPlaying = true
    }

    private fun pauseVideo() {
        webView?.loadUrl("javascript:pauseVideo()")

        State.isPlaying = false
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (audioFocusRequest != null) {
                audioManager.abandonAudioFocusRequest(audioFocusRequest!!)
            }
        } else {
            audioManager.abandonAudioFocus { }
        }
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener {  }
                .build()
            audioManager.requestAudioFocus(audioFocusRequest!!)
        } else {
            audioManager.requestAudioFocus(
                { },
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun seekPrev() {
        val songIndexTemp = currentSongIndex ?: 0
        if (currentTime - songArray[songIndexTemp].startTime <= PREV_SONG_THRES) {
            val nextSongIndex = if (songIndexTemp - 1 < 0) songArray.size - 1 else songIndexTemp - 1
            seekSong(songIndexTemp, nextSongIndex)
        } else {
            webView?.loadUrl("javascript:seekTo(${songArray[songIndexTemp].startTime})")
        }
    }

    private fun seekNext() {
        val songIndexTemp = currentSongIndex ?: 0

        when(repeatState) {
            RepeatState.SHUFFLE -> {
                seekSong(songIndexTemp, Random.nextInt(songArray.size))
            }
            else -> {
                val nextSongIndex = if (songIndexTemp + 1 >= songArray.size) 0 else songIndexTemp + 1
                seekSong(songIndexTemp, nextSongIndex)
            }
        }
    }

    private fun playStop() {
        if (State.isPlaying) {
            pauseVideo()
            abandonAudioFocus()
        } else {
            requestAudioFocus()
            playVideo()
        }
    }
}