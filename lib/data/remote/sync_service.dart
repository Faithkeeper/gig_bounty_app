import 'dart:developer' as developer;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/sqlite_helper.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SqliteHelper _sqliteHelper = SqliteHelper.instance;

  // Process pending offline actions
  Future<void> processSyncQueue() async {
    try {
      final pendingItems = await _sqliteHelper.getPendingSyncQueue();
      if (pendingItems.isEmpty) return;

      for (var item in pendingItems) {
        final int id = item['id'] as int;
        final String actionType = item['actionType'] as String;
        final Map<String, dynamic> payload =
            jsonDecode(item['payload'] as String);

        if (actionType == 'CREATE_TASK') {
          // Check for duplicate submission using taskId/payload signature
          final taskId =
              payload['id'] ?? _firestore.collection('tasks').doc().id;

          await _firestore.collection('tasks').doc(taskId).set(
              {
                ...payload,
                'createdAt': Timestamp.now(),
              },
              SetOptions(
                  merge: true)); // Prevents duplicates / overwrites safely
        }

        // Clear item from queue once successfully synced
        await _sqliteHelper.clearQueueItem(id);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to process the offline sync queue. Pending actions were retained.',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
