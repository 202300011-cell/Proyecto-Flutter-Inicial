class ApiPost {
  final int id;
  final int userId;
  final String title;
  final String body;

  const ApiPost({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory ApiPost.fromJson(Map<String, dynamic> json) {
    return ApiPost(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
    };
  }
}
