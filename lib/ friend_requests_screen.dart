import 'package:flutter/material.dart';

class FriendRequestsScreen extends StatelessWidget {
  final List<Request> friendRequests;

  FriendRequestsScreen({required this.friendRequests});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friend Requests'),
      ),
      body: ListView.builder(
        itemCount: friendRequests.length,
        itemBuilder: (context, index) {
          final request = friendRequests[index];
          return ListTile(
            title: Text(request.senderName),
            subtitle: Text('Sent you a friend request'),
          );
        },
      ),
    );
  }
}

class Request {
  final String senderUid;
  final String senderName;
  final String senderProfilePictureUrl;
  final bool isFriendRequest;

  Request({
    required this.senderUid,
    required this.senderName,
    required this.senderProfilePictureUrl,
    required this.isFriendRequest,
  });

  factory Request.fromMap(Map<dynamic, dynamic> map) {
    return Request(
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? 'Anonymous',
      senderProfilePictureUrl: map['senderProfilePictureUrl'] ?? '',
      isFriendRequest: map['isFriendRequest'] ?? false,
    );
  }
}
