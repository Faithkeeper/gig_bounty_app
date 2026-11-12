import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a review and recalculate the reviewee's average rating.
  Future<void> submitReview(ReviewModel review) async {
    final reviewRef = _firestore.collection('reviews').doc(review.id);
    final userRef = _firestore.collection('users').doc(review.revieweeId);
    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: review.revieweeId)
        .get();
    final userSnapshot = await userRef.get();
    final existingReviewSnapshot = await reviewRef.get();

    var totalRating = review.rating;
    var count = 1;

    for (final doc in reviewsSnap.docs) {
      if (doc.id != review.id) {
        totalRating += (doc.data()['rating'] ?? 0.0).toDouble();
        count++;
      }
    }

    final batch = _firestore.batch()..set(reviewRef, review.toMap());

    if (userSnapshot.exists) {
      batch.update(userRef, {
        'rating': totalRating / count,
        if (!existingReviewSnapshot.exists)
          'jobsCompleted': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  // Stream reviews for a specific user/provider
  Stream<List<ReviewModel>> getReviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReviewModel.fromMap(doc.data()))
          .toList();
    });
  }
}
