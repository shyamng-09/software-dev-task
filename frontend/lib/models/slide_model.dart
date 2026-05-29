class SlideModel {
  final String id;
  final String type;
  final String title;
  final String content;
  final List<String> options;
  final String correctAnswer;
  final int timer;

  SlideModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.options = const [],
    this.correctAnswer = '',
    this.timer = 10,
  });

  factory SlideModel.fromJson(Map<String, dynamic> json) {
    return SlideModel(
      id: json['id'] ?? '',
      type: json['type'] ?? 'info',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '',
      timer: json['timer'] ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'options': options,
      'correctAnswer': correctAnswer,
      'timer': timer,
    };
  }

  SlideModel copyWith({
    String? id,
    String? type,
    String? title,
    String? content,
    List<String>? options,
    String? correctAnswer,
    int? timer,
  }) {
    return SlideModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      timer: timer ?? this.timer,
    );
  }
}
