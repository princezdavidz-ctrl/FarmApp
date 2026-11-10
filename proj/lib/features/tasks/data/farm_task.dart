class FarmTask {
  const FarmTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.category,
    required this.status,
    this.assignedTo,
    this.assigneeName,
    this.notes,
    this.dueAt,
  });

  final String id;
  final String title;
  final String priority;
  final String category;
  final String status;
  final String? assignedTo;
  final String? assigneeName;
  final String? notes;
  final DateTime? dueAt;

  bool get isCompleted => status == 'completed';

  factory FarmTask.fromJson(Map<String, dynamic> json) {
    final assignee = json['assignee'] as Map<String, dynamic>?;
    return FarmTask(
      id: '${json['id']}',
      title: '${json['title'] ?? ''}',
      priority: '${json['priority'] ?? 'normal'}',
      category: '${json['category'] ?? 'other'}',
      status: '${json['status'] ?? 'open'}',
      assignedTo: json['assigned_to']?.toString(),
      assigneeName: assignee?['name'] as String?,
      notes: json['notes'] as String?,
      dueAt: json['due_at'] == null
          ? null
          : DateTime.tryParse('${json['due_at']}'),
    );
  }
}
