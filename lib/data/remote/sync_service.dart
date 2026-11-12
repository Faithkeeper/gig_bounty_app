import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../local/sqlite_helper.dart';

class SyncService {
  factory SyncService() => instance;

  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SqliteHelper _sqliteHelper = SqliteHelper.instance;
  final Connectivity _connectivity = Connectivity();
  bool _isListening = false;
  Future<void>? _syncInProgress;

  void initializeSyncListener() {
    if (_isListening) return;
    _isListening = true;

    unawaited(_checkAndSync());
    _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          debugPrint('Connectivity restored. Processing sync queue...');
          unawaited(processSyncQueue());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Failed to monitor connectivity changes.',
          name: 'SyncService',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> _checkAndSync() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.any((result) => result != ConnectivityResult.none)) {
        await processSyncQueue();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to check connectivity for offline sync.',
        name: 'SyncService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // Process pending offline actions
  Future<void> processSyncQueue() {
    return _syncInProgress ??= _processSyncQueue().whenComplete(() {
      _syncInProgress = null;
    });
  }

  Future<void> _processSyncQueue() async {
    try {
      final pendingItems = await _sqliteHelper.getPendingSyncQueue();
      if (pendingItems.isEmpty) return;

      for (var item in pendingItems) {
        final int id = item['id'] as int;
        await syncItemWithConflictResolution(
          Map<String, dynamic>.from(item),
        );

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

  Future<void> syncItemWithConflictResolution(
      Map<String, dynamic> queueItem) async {
    final actionType = queueItem['action_type'] ?? queueItem['actionType'];
    final documentId = queueItem['document_id'] ?? queueItem['documentId'];
    final rawPayload = queueItem['payload'];
    final createdAt = queueItem['created_at'] ?? queueItem['timestamp'];

    if (actionType is! String) {
      throw const FormatException('Sync queue item has no action type.');
    }
    if (rawPayload is! String) {
      throw const FormatException('Sync queue item has no valid payload.');
    }
    if (createdAt is! String) {
      throw const FormatException('Sync queue item has no creation timestamp.');
    }

    final decodedPayload = jsonDecode(rawPayload);
    if (decodedPayload is! Map) {
      throw const FormatException('Sync queue payload must be a JSON object.');
    }
    final payload = Map<String, dynamic>.from(decodedPayload);
    final localTimestamp = DateTime.parse(createdAt);
    final resolvedDocumentId = documentId ?? payload['id'];
    if (resolvedDocumentId is! String || resolvedDocumentId.isEmpty) {
      throw const FormatException('Sync queue item has no document ID.');
    }

    final docRef = _firestore
        .collection(_getCollectionForAction(actionType))
        .doc(resolvedDocumentId);
    final serverDoc = await docRef.get();

    if (serverDoc.exists) {
      final serverData = serverDoc.data();
      final serverTimestamp = _toDateTime(
        serverData?['updatedAt'] ?? serverData?['createdAt'],
      );
      if (serverTimestamp != null && serverTimestamp.isAfter(localTimestamp)) {
        debugPrint(
          'Conflict resolved: Server version is newer for '
          '$resolvedDocumentId. Skipping local queue item.',
        );
        return;
      }
    }

    payload['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(payload, SetOptions(merge: true));
  }

  String _getCollectionForAction(String actionType) {
    switch (actionType) {
      case 'CREATE_TASK':
      case 'UPDATE_TASK':
        return 'tasks';
      default:
        throw UnsupportedError('Unsupported offline sync action: $actionType');
    }
  }

  DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
