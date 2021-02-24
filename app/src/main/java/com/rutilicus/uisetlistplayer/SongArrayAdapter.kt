package com.rutilicus.uisetlistplayer

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.TextView

class SongArrayAdapter(context: Context): BaseAdapter() {
    var songArray = arrayOf<Song>()
    private val layoutInflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater

    override fun getCount(): Int {
        return songArray.size
    }

    override fun getItem(position: Int): Any {
        return songArray[position]
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
        var newView = convertView ?: layoutInflater.inflate(R.layout.layout_song_elem, parent, false)

        newView.findViewById<TextView>(R.id.text_song_name).text = songArray[position].songName
        newView.findViewById<TextView>(R.id.text_artist).text = songArray[position].artist
        newView.findViewById<TextView>(R.id.text_movie_name).text = songArray[position].movieName

        return newView
    }
}
