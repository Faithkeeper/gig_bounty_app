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
  Future<void> acceptBid(BidModel bid, String taskId) async {
    final batch = _firestore.batch();

    // 1. Mark this bid as Accepted
    final acceptedBidRef = _firestore.collection('bids').doc(bid.id);
    batch.update(acceptedBidRef, {'status': 'Accepted'});

    // 2. Update task status to 'In Progress' and assign provider
    final taskRef = _firestore.collection('tasks').doc(taskId);
    batch.update(taskRef, {
      'status': 'In Progress',
      'assignedProvider': bid.providerName,
    });

    // 3. Fetch all sibling bids for this task to reject them
    final querySnapshot = await _firestore
        .collection('bids')
        .where('taskId', isEqualTo: taskId)
        .get();

    for (var doc in querySnapshot.docs) {
      if (doc.id != bid.id) {
        batch.update(doc.reference, {'status': 'Rejected'});
      }
    }

    await batch.commit();
  }

  // Reject an individual bid
  Future<void> rejectBid(String bidId) async {
    await _firestore.collection('bids').doc(bidId).update({'status': 'Rejected'});
  }
}