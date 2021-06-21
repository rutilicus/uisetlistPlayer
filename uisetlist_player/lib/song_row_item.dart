import 'package:flutter/material.dart';
import 'package:uisetlist_player/song.dart';

class SongRowItem extends StatelessWidget {
  final Song song;

  SongRowItem(this.song);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: Text(song.songName,
              style: DefaultTextStyle.of(context).style.apply(fontSizeFactor: 2)),
        ),
        SizedBox(
          width: double.infinity,
          child: Text(song.artist),
        ),
        SizedBox(
          width: double.infinity,
          child: Text(song.movie.name),
        ),
      ],
    );
  }
}
