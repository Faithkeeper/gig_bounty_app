import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import '../local/sqlite_helper.dart';
import '../../models/bid_model.dart';
import 'sync_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream real-time tasks, caching Firestore results for offline reading.
  Stream<List<TaskModel>> getTasks() {
    return _firestore
        .collection('tasks')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        final tasks = snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.data(), id: doc.id))
            .toList();
        await SqliteHelper.instance.cacheTasks(tasks);
        return tasks;
      } catch (_) {
        return SqliteHelper.instance.getCachedTasks();
      }
    });
  }

  // Publish a new task to Firestore
  Future<void> createTask(TaskModel task) async {
    final taskReference =
        _firestore.collection('tasks').doc(task.id.isEmpty ? null : task.id);
    final taskData = task.toMap()..['id'] = taskReference.id;

    try {
      // Try online write first
      await taskReference.set(taskData);
    } catch (e) {
      // If offline, queue action locally
      final payload = Map<String, dynamic>.from(taskData)
        ..['createdAt'] = task.createdAt.toIso8601String()
        ..['deadline'] = task.deadline?.toIso8601String();
      await SqliteHelper.instance.queueOfflineMutation(
        actionType: 'CREATE_TASK',
        documentId: taskReference.id,
        payload: payload,
      );
    }
    // Attempt background sync check
    await SyncService().processSyncQueue();
  }

  // Delete a task and any bids associated with it.
  Future<void> deleteTask(String taskId) async {
    final bidsSnapshot = await _firestore
        .collection('bids')
        .where('taskId', isEqualTo: taskId)
        .get();

    const maxBidDeletesPerBatch = 499;
    var start = 0;
    while (bidsSnapshot.docs.length - start > maxBidDeletesPerBatch) {
      final batch = _firestore.batch();
      for (var index = start; index < start + maxBidDeletesPerBatch; index++) {
        batch.delete(bidsSnapshot.docs[index].reference);
      }
      await batch.commit();
      start += maxBidDeletesPerBatch;
    }

    final batch = _firestore.batch();
    for (var index = start; index < bidsSnapshot.docs.length; index++) {
      batch.delete(bidsSnapshot.docs[index].reference);
    }
    batch.delete(_firestore.collection('tasks').doc(taskId));
    await batch.commit();
  }

  Future<void> acceptBid(
      {required String taskId, required BidModel winningBid}) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'status': 'In Progress',
      'assignedProviderId': winningBid.providerId,
      'assignedProviderName': winningBid.providerName,
    });

    // Optional: Record notification event for target user
    await _firestore.collection('notifications').add({
      'userId': winningBid.providerId,
      'title': 'Bid Accepted!',
      'body': 'Your bid was accepted. Get to work!',
      'timestamp': FieldValue.serverTimestamp(),
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

  // Update task status and close its contract when completion is authorized.
  Future<void> updateTaskStatus(String taskId, String newStatus,
      {required String actorUid, String? completionNote}) async {
    final taskRef = _firestore.collection('tasks').doc(taskId);

    await _firestore.runTransaction((transaction) async {
      final taskSnap = await transaction.get(taskRef);
      if (!taskSnap.exists) {
        throw Exception('Task not found.');
      }

      final data = taskSnap.data()!;
      final currentStatus = data['status'] as String? ?? 'Open';
      final assignedProviderId = data['assignedProviderId'] as String?;
      final posterId = data['posterId'] as String?;
      final contractId = data['contractId'] as String?;

      if (newStatus == 'Completed') {
        if (currentStatus != 'In Progress') {
          throw Exception(
              'Only tasks that are In Progress can be marked Completed.');
        }
        if (actorUid != assignedProviderId && actorUid != posterId) {
          throw Exception(
              'Unauthorized: Only the assigned provider or task owner can complete this task.');
        }
      }

      DocumentReference<Map<String, dynamic>>? contractRef;
      DocumentSnapshot<Map<String, dynamic>>? contractSnapshot;
      if (newStatus == 'Completed' &&
          contractId != null &&
          contractId.isNotEmpty) {
        contractRef = _firestore.collection('contracts').doc(contractId);
        contractSnapshot = await transaction.get(contractRef);
      }

      final updates = <String, dynamic>{
        'status': newStatus,
        if (completionNote != null && completionNote.isNotEmpty)
          'completionNote': completionNote,
        if (newStatus == 'Completed')
          'completedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(taskRef, updates);

      if (contractRef != null && contractSnapshot?.exists == true) {
        transaction.update(contractRef, {
          'status': 'Completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Fetch task history for a specific user (as poster or assigned provider)
  Future<List<TaskModel>> getUserTaskHistory(String userId) async {
    try {
      // Fetch tasks where user is customer
      final customerQuery = await _firestore
          .collection('tasks')
          .where('posterId', isEqualTo: userId)
          .where('status', whereIn: ['Completed', 'Cancelled']).get();

      // Fetch tasks where user is assigned service provider
      final providerQuery = await _firestore
          .collection('tasks')
          .where('assignedProviderId', isEqualTo: userId)
          .where('status', whereIn: ['Completed', 'Cancelled']).get();

      final Map<String, TaskModel> taskMap = {};

      for (var doc in customerQuery.docs) {
        taskMap[doc.id] = TaskModel.fromMap(doc.data(), id: doc.id);
      }
      for (var doc in providerQuery.docs) {
        taskMap[doc.id] = TaskModel.fromMap(doc.data(), id: doc.id);
      }

      // Sort by creation date descending
      final tasks = taskMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tasks;
    } catch (e) {
      throw Exception('Failed to load task history: ${e.toString()}');
    }
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
