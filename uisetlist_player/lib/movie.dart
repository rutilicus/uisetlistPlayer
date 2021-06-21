class Movie {
  final String movieId;
  final String name;
  final String date;

  Movie({required this.movieId, required this.name, required this.date});

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
        movieId: json['movieId'],
        name: json['name'],
        date: json['date'],
    );
  }

  Map<String, dynamic> joJson() => {
    'movieId': movieId,
    'name': name,
    'date': date
  };
}
