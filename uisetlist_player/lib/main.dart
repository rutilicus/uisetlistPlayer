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

void main() async {
  if (!UniversalPlatform.isWeb) {
    WidgetsFlutterBinding.ensureInitialized();

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
}

class MainPage extends StatelessWidget {
  MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
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
