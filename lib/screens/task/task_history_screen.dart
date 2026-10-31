import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/user_profile.dart';
import '../../data/remote/task_service.dart';

class TaskHistoryScreen extends StatefulWidget {
  final UserProfile userProfile;

  const TaskHistoryScreen({super.key, required this.userProfile});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  final TaskService _taskService = TaskService();
  late Future<List<TaskModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _taskService.getUserTaskHistory(widget.userProfile.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
      ),
      body: FutureBuilder<List<TaskModel>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'No completed or cancelled tasks found.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isCompleted = task.status == 'Completed';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${task.category} • R${task.budget.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      Text('Role: ${task.posterId == widget.userProfile.uid ? "Customer" : "Service Provider"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(task.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: isCompleted ? Colors.green : Colors.redAccent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}