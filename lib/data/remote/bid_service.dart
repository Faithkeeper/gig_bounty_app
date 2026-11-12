import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/bid_model.dart';

class BidService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a new bid for a task
  Future<void> submitBid(BidModel bid) async {
    await _firestore.collection('bids').doc(bid.id).set(bid.toMap());
  }

  // Stream all bids for a specific task
  Stream<List<BidModel>> getBidsForTask(String taskId) {
    return _firestore
        .collection('bids')
        .where('taskId', isEqualTo: taskId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BidModel.fromMap(doc.data())).toList();
    });
  }

  // Accept a specific bid and reject all other competing bids for the task
  Future<void> acceptBid(BidModel winningBid, String taskId) async {
    final bidsCollection = _firestore.collection('bids');
    final taskRef = _firestore.collection('tasks').doc(taskId);
    final winningBidRef = bidsCollection.doc(winningBid.id);
    final otherBidsSnapshot = await bidsCollection
        .where('taskId', isEqualTo: taskId)
        .get();

    await _firestore.runTransaction((transaction) async {
      final taskSnapshot = await transaction.get(taskRef);
      final winningBidSnapshot = await transaction.get(winningBidRef);
      final competingBidSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final bidDocument in otherBidsSnapshot.docs) {
        if (bidDocument.id != winningBid.id) {
          competingBidSnapshots
              .add(await transaction.get(bidDocument.reference));
        }
      }

      if (!taskSnapshot.exists) {
        throw Exception('Task does not exist.');
      }

      final taskStatus = taskSnapshot.data()?['status'] as String? ?? 'Open';
      if (taskStatus != 'Open') {
        throw Exception('This task is no longer open for bid acceptance.');
      }

      if (!winningBidSnapshot.exists ||
          winningBidSnapshot.data()?['taskId'] != taskId) {
        throw Exception('Winning bid does not exist for this task.');
      }

      transaction.update(taskRef, {
        'status': 'In Progress',
        'assignedProviderId': winningBid.providerId,
        'assignedProviderName': winningBid.providerName,
      });
      transaction.update(winningBidRef, {'status': 'Accepted'});

      for (final bidSnapshot in competingBidSnapshots) {
        if (bidSnapshot.exists && bidSnapshot.data()?['taskId'] == taskId) {
          transaction.update(bidSnapshot.reference, {'status': 'Rejected'});
        }
      }
    });
  }

  // Reject an individual bid
  Future<void> rejectBid(String bidId) async {
    await _firestore.collection('bids').doc(bidId).update({'status': 'Rejected'});
  }
}