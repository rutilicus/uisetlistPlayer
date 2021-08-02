import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uisetlist_player/player_control_area.dart';
import 'package:uisetlist_player/repeat_state.dart';
import 'package:uisetlist_player/song.dart';
import 'package:uisetlist_player/song_row_item.dart';
import 'package:uisetlist_player/ytview.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  if (!UniversalPlatform.isWeb) {
    WidgetsFlutterBinding.ensureInitialized();

    AwesomeNotifications().initialize(
      'resource://drawable/ic_stat_play',
      [
        NotificationChannel(
          channelKey: 'uisetlist_notification',
          channelName: 'Background play',
          channelDescription: 'Background play',
          locked: true,
          enableVibration: false
        )
      ]
    );

    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    if (UniversalPlatform.isAndroid) {
      await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'uisetlistPlayer',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
      ),
      home: RootWidget(),
    );
  }
}

class RootWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RootChangeNotifier>(
      create: (_) => RootChangeNotifier(),
      child: MainPage(title: 'uisetlistPlayer'),
    );
  }
}

class RootChangeNotifier extends ChangeNotifier {
  bool isPlaying = false;
  List<Song> songs = List<Song>.empty();
  RepeatState repeatState = RepeatState.OFF;
  int currentSongIndex = -1;
  InAppWebViewController? webViewController;
  int currentTime = 0;

  static const int prevSongThres = 5;
  static const int notificationId = 5151;

  // TODO: URLを変えられる仕組みにする
  String url = "https://uisetlist.herokuapp.com/";
  static const String apiPath = "api/song";

  // HTTP通信による曲一覧取得メソッド
  Future<void> _getData() async {
    final response = await http.get(Uri.parse(url + apiPath));

    if (response.statusCode == 200) {
      _setSongs(List<Song>.from(jsonDecode(utf8.decode(response.bodyBytes)).map(
              (json) => Song.fromJson(json))));
    } else {
      // TODO: HTTP通信に失敗した場合の処理を入れる
      throw Exception('Failed to load all song data');
    }
  }

  RootChangeNotifier() {
    Future<void>.sync(() => _getData());
  }

  void setPlayingState(bool newState) {
    if (this.isPlaying != newState) {
      this.isPlaying = newState;
      notifyListeners();
    }
  }

  void _setSongs(List<Song> newSongs) {
    this.songs = newSongs;
    notifyListeners();
  }

  void advanceRepeatState() {
    this.repeatState = RepeatState.values[
    (this.repeatState.index + 1) % RepeatState.values.length
    ];
    notifyListeners();
  }

  void setRepeatState(RepeatState newState) {
    if (this.repeatState != newState) {
      this.repeatState = newState;
      notifyListeners();
    }
  }

  void setCurrentSongIndex(int newIndex) {
    if (this.currentSongIndex != newIndex) {
      this.currentSongIndex = newIndex;
      notifyListeners();
    }
  }

  void setWebViewController(InAppWebViewController? controller) {
    this.webViewController = controller;
    notifyListeners();
  }

  void setCurrentTime(int time) {
    this.currentTime = time;
  }

  void seekPrev() {
    if (currentSongIndex >= 0 && currentSongIndex < songs.length) {
      if (currentTime - songs[currentSongIndex].time <= prevSongThres) {
        int nextSongIndex = (currentSongIndex + songs.length - 1) % songs.length;
        webViewController?.evaluateJavascript(
            source: 'loadVideoById("${songs[nextSongIndex].movie.movieId}", ${songs[nextSongIndex].time});'
        );
        setCurrentSongIndex(nextSongIndex);
      } else {
        webViewController?.evaluateJavascript(
            source: 'loadVideoById("${songs[currentSongIndex].movie.movieId}", ${songs[currentSongIndex].time});'
        );
      }
    }
  }

  void seekNext() {
    int nextSongIndex = (currentSongIndex + 1) % songs.length;
    webViewController?.evaluateJavascript(
        source: 'loadVideoById("${songs[nextSongIndex].movie.movieId}", ${songs[nextSongIndex].time});'
    );
    setCurrentSongIndex(nextSongIndex);
  }

  void pausePlay() {
    if (isPlaying) {
      webViewController?.evaluateJavascript(
          source: 'pauseVideo();'
      );
    } else {
      webViewController?.evaluateJavascript(
          source: 'playVideo();'
      );
    }
  }

  void pause() {
    webViewController?.evaluateJavascript(
        source: 'pauseVideo();'
    );
  }

  Future<bool> createPlayerNotification() async {
    try {
      return await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'uisetlist_notification',
            title: (currentSongIndex < 0 || currentSongIndex >= songs.length)
                ? '' : songs[currentSongIndex].songName,
            autoCancel: false,
            showWhen: false,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'MEDIA_PREV',
              icon: 'resource://drawable/res_ic_prev',
              label: 'Previous',
              buttonType: ActionButtonType.KeepOnTop,
              autoCancel: false
            ),
            NotificationActionButton(
                key: 'MEDIA_PLAY',
                icon: isPlaying ? 'resource://drawable/res_ic_pause' : 'resource://drawable/res_ic_play',
                label: isPlaying ? 'Pause' : 'Play',
                buttonType: ActionButtonType.KeepOnTop,
                autoCancel: false
            ),
            NotificationActionButton(
                key: 'MEDIA_NEXT',
                icon: 'resource://drawable/res_ic_next',
                label: 'Next',
                buttonType: ActionButtonType.KeepOnTop,
                autoCancel: false
            ),
            /*
            NotificationActionButton(
                key: 'MEDIA_CLOSE',
                icon: 'resource://drawable/res_ic_close',
                label: 'Close',
                buttonType: ActionButtonType.KeepOnTop,
            ),
             */
          ]);
    } on PlatformException catch (e) {
      print(e);
    }

    return false;
  }

  Future<void> cancelPlayerNotification() async {
    AwesomeNotifications().cancel(notificationId);
  }
}

class MainPage extends StatelessWidget {
  MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  void processMediaControl(context, actionReceived) {
    switch (actionReceived.buttonKeyPressed) {
      case 'MEDIA_PREV':
        Provider.of<RootChangeNotifier>(context, listen: false).seekPrev();
        break;

      case 'MEDIA_PLAY':
      case 'MEDIA_PAUSE':
        Provider.of<RootChangeNotifier>(context, listen: false).pausePlay();
        break;

      case 'MEDIA_NEXT':
        Provider.of<RootChangeNotifier>(context, listen: false).seekNext();
        break;

      case 'MEDIA_CLOSE':
        Provider.of<RootChangeNotifier>(context, listen: false).pause();
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 通知のリスナ設定
    // Statelessだからもしかしたら破棄されちゃうかも、それだったら後で考える
    AwesomeNotifications().actionStream.listen(
            (receivedNotification){
          if (!StringUtils.isNullOrEmpty(receivedNotification.buttonKeyPressed)) {
            processMediaControl(context, receivedNotification);
          }
        }
    );

    // 通知の破棄・生成設定
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message != null) {
        if (message == AppLifecycleState.resumed.toString()) {
          Future<void>.sync(() => Provider.of<RootChangeNotifier>(context, listen: false).cancelPlayerNotification());
        } else if (message == AppLifecycleState.paused.toString()) {
          Provider.of<RootChangeNotifier>(context, listen: false).pause();
          Future<bool>.sync(() => Provider.of<RootChangeNotifier>(context, listen: false).createPlayerNotification());
        } else if (message == AppLifecycleState.detached.toString()) {
          Future<void>.sync(() => Provider.of<RootChangeNotifier>(context, listen: false).cancelPlayerNotification());
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
          children: [
            Flexible(
                child: Consumer<RootChangeNotifier>(
                    builder: (_, RootChangeNotifier notifier, __) =>
                        ListView.separated(
                          itemCount: notifier.songs.length,
                          itemBuilder: (BuildContext context, int index) {
                            return GestureDetector(
                              onTap: () {
                                if (UniversalPlatform.isWeb) {
                                  final data = <String, Map<String, dynamic>>{
                                    'loadVideoById': {
                                      'id': notifier.songs[index].movie.movieId,
                                      'time': notifier.songs[index].time,
                                    }
                                  };
                                  final jsonEncoder = JsonEncoder();
                                  final json = jsonEncoder.convert(data);
                                  html.window.postMessage(json, '*');
                                } else {
                                  if (notifier.webViewController != null) {
                                    notifier.webViewController
                                        ?.evaluateJavascript(
                                        source: 'loadVideoById("${notifier.songs[index].movie.movieId}", ${notifier.songs[index].time});'
                                    );
                                  }
                                }

                                notifier.setCurrentSongIndex(index);
                              } ,
                              child: SongRowItem(notifier.songs[index]),
                            );
                          },
                          separatorBuilder: (BuildContext context, int index) {
                            return Divider(height: 1);
                          },))),
            Container(
              height: 1,
              child: YTView(),
            ),
            PlayerControlArea()]
      ),
    );
  }
}
