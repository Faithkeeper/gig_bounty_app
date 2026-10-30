import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import '../local/sqlite_helper.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream real-time tasks, caching Firestore results for offline reading.
  Stream<List<TaskModel>> getTasks() {
    return _firestore.collection('tasks').snapshots().asyncMap((snapshot) async {
      try {
        final tasks =
            snapshot.docs.map((doc) => TaskModel.fromMap(doc.data())).toList();
        await SqliteHelper.instance.cacheTasks(tasks);
        return tasks;
      } catch (_) {
        return SqliteHelper.instance.getCachedTasks();
      }
    });
  }

  // Publish a new task to Firestore
  Future<void> createTask(TaskModel task) async {
    await _firestore.collection('tasks').doc(task.id).set(task.toMap());
  }

  // Delete/Cancel an eligible task
  Future<void> deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  // Update task operational status (e.g., 'In Progress' -> 'Completed')
  Future<void> updateTaskStatus(String taskId, String newStatus,
      {String? completionNote}) async {
    final Map<String, dynamic> updateData = {'status': newStatus};
    if (completionNote != null) {
      updateData['completionNote'] = completionNote;
    }
    await _firestore.collection('tasks').doc(taskId).update(updateData);
  }

  // Fetch task history for a specific user (as poster or assigned provider)
  Stream<List<TaskModel>> getUserTaskHistory(String userId) {
    return _firestore.collection('tasks').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data()))
          .where((task) => task.posterId == userId || task.status == 'Completed')
          .toList();
    });
  }

  Future<void> updateTaskDetails({
    required String taskId,
    required String title,
    required String description,
    required double budget,
    required String location,
    DateTime? deadline,
  }) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'title': title,
      'description': description,
      'budget': budget,
      'location': location,
      'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
    });
  }
}