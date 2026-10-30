class TaskModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final double budget;
  final String location;
  final String posterId;
  final String posterName;
  String status; // 'Open', 'In Progress', 'Completed'
  final String? assignedProvider;
  final String? completionNote;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.location,
    required this.posterId,
    required this.posterName,
    this.status = 'Open',
    this.assignedProvider,
    this.completionNote,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'budget': budget,
      'location': location,
      'posterId': posterId,
      'posterName': posterName,
      'status': status,
      'assignedProvider': assignedProvider,
      'completionNote': completionNote,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      budget: (map['budget'] ?? 0.0).toDouble(),
      location: map['location'] ?? '',
      posterId: map['posterId'] ?? '',
      posterName: map['posterName'] ?? '',
      status: map['status'] ?? 'Open',
      assignedProvider: map['assignedProvider'],
      completionNote: map['completionNote'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}