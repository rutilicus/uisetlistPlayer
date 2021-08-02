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
                Provider.of<RootChangeNotifier>(context, listen: false).seekPrev();
              },
            ),
            IconButton(
              icon: Consumer<RootChangeNotifier>(
                builder: (_, RootChangeNotifier notifier, __) =>
                    Icon(notifier.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              onPressed: () {
                Provider.of<RootChangeNotifier>(context, listen: false).pausePlay();
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                Provider.of<RootChangeNotifier>(context, listen: false).seekNext();
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
