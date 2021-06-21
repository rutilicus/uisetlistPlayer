import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uisetlist_player/main.dart';
import 'package:uisetlist_player/repeat_state.dart';
import 'package:uisetlist_player/song.dart';

class PlayerControlArea extends StatelessWidget {
  final int prevSongThres = 5;

  IconData getRepeatStateIcon(RepeatState state) {
    switch (state) {
      case RepeatState.OFF:
        return Icons.repeat;
      case RepeatState.ON:
        return Icons.repeat_on_outlined;
      case RepeatState.SHUFFLE:
        return Icons.shuffle_on_outlined;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Consumer<RootChangeNotifier>(
            builder: (_, RootChangeNotifier notifier, __) =>
                Text(0 <= notifier.currentSongIndex &&
                    notifier.currentSongIndex < notifier.songs.length ?
                notifier.songs[notifier.currentSongIndex].songName : "")
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () {
                List<Song> songs =
                  Provider.of<RootChangeNotifier>(context, listen: false).songs;
                int currentTime =
                    Provider.of<RootChangeNotifier>(context, listen: false)
                .currentTime;
                int currentSongIndex =
                Provider.of<RootChangeNotifier>(context, listen: false)
                .currentSongIndex;

                if (currentSongIndex >= 0 && currentSongIndex < songs.length) {
                  if (currentTime - songs[currentSongIndex].time <= prevSongThres) {
                    int nextSongIndex = (currentSongIndex + songs.length - 1) % songs.length;
                    Provider.of<RootChangeNotifier>(context, listen: false)
                        .webViewController?.evaluateJavascript(
                        source: 'loadVideoById("${songs[nextSongIndex].movie.movieId}", ${songs[nextSongIndex].time});'
                    );
                    Provider.of<RootChangeNotifier>(context, listen: false)
                        .setCurrentSongIndex(nextSongIndex);
                  } else {
                    Provider.of<RootChangeNotifier>(context, listen: false)
                        .webViewController?.evaluateJavascript(
                        source: 'loadVideoById("${songs[currentSongIndex].movie.movieId}", ${songs[currentSongIndex].time});'
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: Consumer<RootChangeNotifier>(
                builder: (_, RootChangeNotifier notifier, __) =>
                    Icon(notifier.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              onPressed: () {
                if (Provider.of<RootChangeNotifier>(context, listen: false).isPlaying) {
                  Provider.of<RootChangeNotifier>(context, listen: false)
                      .webViewController?.evaluateJavascript(
                      source: 'pauseVideo();'
                  );
                } else {
                  Provider.of<RootChangeNotifier>(context, listen: false)
                      .webViewController?.evaluateJavascript(
                      source: 'playVideo();'
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                List<Song> songs =
                    Provider.of<RootChangeNotifier>(context, listen: false).songs;
                int currentSongIndex =
                    Provider.of<RootChangeNotifier>(context, listen: false)
                        .currentSongIndex;
                int nextSongIndex = (currentSongIndex + 1) % songs.length;
                Provider.of<RootChangeNotifier>(context, listen: false)
                    .webViewController?.evaluateJavascript(
                    source: 'loadVideoById("${songs[nextSongIndex].movie.movieId}", ${songs[nextSongIndex].time});'
                );
                Provider.of<RootChangeNotifier>(context, listen: false)
                    .setCurrentSongIndex(nextSongIndex);
              },
            ),
            IconButton(
                icon: Consumer<RootChangeNotifier>(
                  builder: (_, RootChangeNotifier notifier, __) =>
                      Icon(getRepeatStateIcon(notifier.repeatState)),
                ),
                onPressed: () {
                  Provider.of<RootChangeNotifier>(context, listen: false).advanceRepeatState();
                })
          ],
        ),
      ],
    );
  }
}
