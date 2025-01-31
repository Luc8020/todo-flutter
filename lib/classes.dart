class Todo {
  final String id;
  final String title;
  final String description;
  final bool completed;

  const Todo ({
    required this.description,
    required this.title,
    required this.id,
    required this.completed
});

  factory Todo.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'description': String description,
        'title': String title,
        'id': String id,
        'completed': bool completed
      } =>
        Todo(
          description: description,
          title: title,
          id: id,
          completed: completed,
        ),
    _ => throw const FormatException('Failed to load'),
    };
  }
}