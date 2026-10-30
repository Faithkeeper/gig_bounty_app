import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a review and recalculate provider reputation metrics
  Future<void> submitReview(ReviewModel review) async {
    final reviewRef = _firestore.collection('reviews').doc(review.id);
    final userRef = _firestore.collection('users').doc(review.revieweeId);

    await _firestore.runTransaction((transaction) async {
      // 1. Save the review document
      transaction.set(reviewRef, review.toMap());

      // 2. Fetch current user profile metrics
      final userSnapshot = await transaction.get(userRef);
      if (userSnapshot.exists) {
        final data = userSnapshot.data() as Map<String, dynamic>;
        double currentRating = (data['rating'] ?? 0.0).toDouble();
        int jobsCompleted = (data['jobsCompleted'] ?? 0) as int;

        // Calculate new weighted rating and increment jobs completed
        int newJobsCount = jobsCompleted + 1;
        double newRating = ((currentRating * jobsCompleted) + review.rating) / newJobsCount;

        // 3. Update user profile with new reputation score
        transaction.update(userRef, {
          'rating': newRating,
          'jobsCompleted': newJobsCount,
        });
      }
    });
  }

  // Stream reviews for a specific user/provider
  Stream<List<ReviewModel>> getReviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data())).toList();
    });
  }
}