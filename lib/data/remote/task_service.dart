import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import '../local/sqlite_helper.dart';
import '../../models/bid_model.dart';

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

  Future<void> acceptBid({required String taskId, required BidModel winningBid}) async {
  // Update task status and assign the provider UID + Name
    await _firestore.collection('tasks').doc(taskId).update({
      'status': 'In Progress',
      'assignedProviderId': winningBid.providerId, // Secure UID
      'assignedProviderName': winningBid.providerName, // Display Name
    });
  }

  Future<void> rejectBid(String bidId) async {
  try {
    await _firestore.collection('bids').doc(bidId).update({
      'status': 'Rejected',
    });
  } catch (e) {
    throw Exception('Failed to reject bid: ${e.toString()}');
  }
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