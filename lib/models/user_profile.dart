class UserProfile {
  final String uid;
  final String email;
  final String fullName;
  final String role; // 'Customer' or 'Service Provider'
  final double rating;
  final int jobsCompleted;

  UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.rating = 0.0,
    this.jobsCompleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'rating': rating,
      'jobsCompleted': jobsCompleted,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'Customer',
      rating: (map['rating'] ?? 0.0).toDouble(),
      jobsCompleted: map['jobsCompleted'] ?? 0,
    );
  }
}