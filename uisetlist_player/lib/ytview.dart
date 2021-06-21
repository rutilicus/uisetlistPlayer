import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:uisetlist_player/repeat_state.dart';
import 'package:uisetlist_player/song.dart';
import 'package:universal_html/html.dart' as html;
import 'main.dart';
import 'ui_fake.dart' if (dart.library.html) 'dart:ui' as ui;
import 'package:universal_platform/universal_platform.dart';

class YTView extends StatelessWidget {
  final String createdViewId = 'ytview_html';
  var _timer;

  @override
  Widget build(BuildContext context) {
    String htmlString = """
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>Player</title>
</head>
<body>
    <div id="player"></div>

    <script>
        let isFlutterInAppWebViewReady = false;
    
        var tag = document.createElement('script');

        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                height: '0',
                width: '0',
                videoId: 'null',
                events: {
                    'onReady': onPlayerReady,
                    'onStateChange': onPlayerStateChange,
                    'onError': onPlayerError
                }
            });
        }

        function onPlayerReady(event) {
        }

        function onPlayerStateChange(event) {
        }
        
        function onPlayerError(event) {
        }

        function seekTo(time) {
            player.seekTo(time);
        }

        function loadVideoById(id, time) {
            player.loadVideoById(id, time, 'small');
        }

        function playVideo() {
            player.playVideo();
        }

        function pauseVideo() {
            player.pauseVideo();
        }

        function getCurrentTime() {
            let data = JSON.stringify(
                {getCurrentTime: player.getCurrentTime()}
            );
            if (isFlutterInAppWebViewReady) {
                window.flutter_inappwebview.callHandler('playerHandler', data);
            } else {
                window.parent.postMessage(data, "*");
            }
        }

        function getPlayerState() {
            let data = JSON.stringify(
                {getPlayerState: player.getPlayerState()}
            );
            if (isFlutterInAppWebViewReady) {
                window.flutter_inappwebview.callHandler('playerHandler', data);
            } else {
                window.parent.postMessage(data, "*");
            }
        }

        window.parent.addEventListener('message', handleMessage, false);
        
        function handleMessage(e) {
            let data = JSON.parse(e.data);
            
            if (data.hasOwnProperty('seekTo')) {
                if (data.seekTo.hasOwnProperty('time')) {
                    seekTo(data.seekTo.time);
                }
            }
            if (data.hasOwnProperty('loadVideoById')) {
                if (data.loadVideoById.hasOwnProperty('id') &&
                    data.loadVideoById.hasOwnProperty('time')) {
                    loadVideoById(data.loadVideoById.id,
                                  data.loadVideoById.time);
                }
            }
            if (data.hasOwnProperty('playVideo')) {
                playVideo();
            }
            if (data.hasOwnProperty('pauseVideo')) {
                pauseVideo();
            }
            if (data.hasOwnProperty('getCurrentTime')) {
                getCurrentTime();
            }
            if (data.hasOwnProperty('getPlayerState')) {
                getPlayerState();
            }            
        }

        window.addEventListener("flutterInAppWebViewPlatformReady",
                                function(event) {
            isFlutterInAppWebViewReady = true;
        });
    </script>
</body>
</html>
  """;

    void _handleMessage(Map<String, dynamic> json) {
      if (json.containsKey('getCurrentTime')) {
        int currentTime = 0;

        if (json['getCurrentTime'] is double) {
          currentTime = json['getCurrentTime'].floor();
        }

        Provider.of<RootChangeNotifier>(context, listen: false)
            .setCurrentTime(currentTime);

        List<Song> songs =
            Provider.of<RootChangeNotifier>(context, listen: false).songs;
        int currentSongIndex =
            Provider.of<RootChangeNotifier>(context, listen: false)
                .currentSongIndex;
        RepeatState repeatState =
            Provider.of<RootChangeNotifier>(context, listen: false).repeatState;

        if (currentSongIndex >= 0 &&
            currentSongIndex < songs.length &&
            currentTime >=  songs[currentSongIndex].endTime) {
          int nextIndex;

          switch (repeatState) {
            case RepeatState.OFF:
              nextIndex = (currentSongIndex + 1) % songs.length;
              break;
            case RepeatState.ON:
              nextIndex = currentSongIndex;
              break;
            case RepeatState.SHUFFLE:
              nextIndex = Random().nextInt(songs.length);
              break;
          }

          Provider.of<RootChangeNotifier>(context, listen: false)
              .webViewController?.evaluateJavascript(
              source: 'loadVideoById("${songs[nextIndex].movie.movieId}", ${songs[nextIndex].time});'
          );
          Provider.of<RootChangeNotifier>(context, listen: false)
              .setCurrentSongIndex(nextIndex);
        }
      }

      if (json.containsKey('getPlayerState')) {
        int playerState = json['getPlayerState'];

        Provider.of<RootChangeNotifier>(context, listen: false)
            .setPlayingState(playerState == 1);
      }
    }

    void _sendMessage(Timer timer) {
      Provider.of<RootChangeNotifier>(context, listen: false)
          .webViewController?.evaluateJavascript(
          source: 'getCurrentTime();'
      );
      Provider.of<RootChangeNotifier>(context, listen: false)
          .webViewController?.evaluateJavascript(
          source: 'getPlayerState();'
      );
    }

    if (UniversalPlatform.isWeb) {
      final html.IFrameElement iframe = html.IFrameElement()
        ..width = '0'
        ..height = '0'
        ..srcdoc = htmlString
        ..style.border = 'none';

      ui.platformViewRegistry.registerViewFactory(
          createdViewId, (int viewId) => iframe);

      return HtmlElementView(viewType: createdViewId,);
    } else {
      return InAppWebView(
        key: GlobalKey(),
        initialData: InAppWebViewInitialData(
          baseUrl: Uri.parse("https://www.youtube.com"),
          data: htmlString,
        ),
        androidOnPermissionRequest: (controller, origin, resources) async {
          return PermissionRequestResponse(
              resources: resources,
              action: PermissionRequestResponseAction.GRANT);
        },
        onWebViewCreated: (InAppWebViewController? controller) {
          Provider.of<RootChangeNotifier>(context, listen: false)
              .setWebViewController(controller);

          controller?.addJavaScriptHandler(
              handlerName: 'playerHandler',
              callback: (args) {
                _handleMessage(jsonDecode(args[0]));
              });
          
          _timer = Timer.periodic(Duration(seconds: 1), _sendMessage);
        },
        initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
                mediaPlaybackRequiresUserGesture: false
            )),
        onCloseWindow: (InAppWebViewController? controller) {
          _timer.cancel();
        },
      );
    }
  }
}
