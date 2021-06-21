import 'package:uisetlist_player/movie.dart';

class Song {
  final int time;
  final int endTime;
  final String songName;
  final String artist;
  final Movie movie;

  Song({
    required this.time, required this.endTime, required this.songName,
    required this.artist, required this.movie});

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(time: json['time'],
      endTime: json['endTime'],
      songName: json['songName'],
      artist: json['artist'],
      movie: new Movie.fromJson(json['movie']));
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'endTime': endTime,
    'songName': songName,
    'artist': artist,
    'movie': movie.joJson()
  };
}
