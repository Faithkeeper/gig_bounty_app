class BidModel {
  final String id;
  final String taskId;
  final String providerId;
  final String providerName;
  final double proposedPrice;
  final String proposalNote;
  String status; // 'Pending', 'Accepted', 'Rejected'
  final double providerRating;

  BidModel({
    required this.id,
    required this.taskId,
    required this.providerId,
    required this.providerName,
    required this.proposedPrice,
    required this.proposalNote,
    this.status = 'Pending',
    this.providerRating = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'providerId': providerId,
      'providerName': providerName,
      'proposedPrice': proposedPrice,
      'proposalNote': proposalNote,
      'status': status,
      'providerRating': providerRating,
    };
  }

  factory BidModel.fromMap(Map<String, dynamic> map) {
    return BidModel(
      id: map['id'] ?? '',
      taskId: map['taskId'] ?? '',
      providerId: map['providerId'] ?? '',
      providerName: map['providerName'] ?? '',
      proposedPrice: (map['proposedPrice'] ?? 0.0).toDouble(),
      proposalNote: map['proposalNote'] ?? '',
      status: map['status'] ?? 'Pending',
      providerRating: (map['providerRating'] ?? 0.0).toDouble(),
    );
  }
}