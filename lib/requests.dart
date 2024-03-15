// requests.dart

class FriendRequest {
  final String senderUid;
  final String receiverUid;
  final String senderName;
  final String senderProfilePictureUrl;
  final String status; // "pending", "accepted", "declined"

  FriendRequest({
    required this.senderUid,
    required this.receiverUid,
    required this.senderName,
    required this.senderProfilePictureUrl,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'senderName': senderName,
      'senderProfilePictureUrl': senderProfilePictureUrl,
      'status': status,
    };
  }

  factory FriendRequest.fromMap(Map<dynamic, dynamic> map) {
    return FriendRequest(
      senderUid: map['senderUid'],
      receiverUid: map['receiverUid'],
      senderName: map['senderName'],
      senderProfilePictureUrl: map['senderProfilePictureUrl'],
      status: map['status'],
    );
  }
}
