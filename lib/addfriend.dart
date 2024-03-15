import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friend Requests Demo',
      home: AddFriendScreen(),
    );
  }
}

class AddFriendScreen extends StatefulWidget {
  @override
  _AddFriendScreenState createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final DatabaseReference _usersReference =
  FirebaseDatabase.instance.reference().child('users');
  final DatabaseReference _friendsReference =
  FirebaseDatabase.instance.reference().child('friends');
  final DatabaseReference _friendRequestsReference =
  FirebaseDatabase.instance.reference().child('friend_requests');

  List<AddFriendUserData> _usersList = [];
  Map<String, List<String>> _friendsMap = {}; // Corrected type

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchFriends();
  }

  void _fetchUsers() {
    _usersReference.onValue.listen((event) {
      final usersMap = event.snapshot.value as Map;
      final List<AddFriendUserData> users = [];

      if (usersMap != null) {
        usersMap.forEach((key, value) {
          if (value is Map &&
              value.containsKey('name') &&
              key != FirebaseAuth.instance.currentUser!.uid) {
            // Check if the user is already a friend
            bool isFriend = false;
            if (_friendsMap
                .containsKey(FirebaseAuth.instance.currentUser!.uid)) {
              isFriend = _friendsMap[FirebaseAuth.instance.currentUser!.uid]!
                  .contains(key);
            }

            users.add(AddFriendUserData.fromMap(value, key, isFriend));
          }
        });
      }

      setState(() {
        _usersList = users;
      });
    });
  }

  void _fetchFriends() {
    _friendsReference
        .child(FirebaseAuth.instance.currentUser!.uid)
        .onValue
        .listen((event) {
      final friendsMap = event.snapshot.value as Map;
      if (friendsMap != null) {
        _friendsMap[FirebaseAuth.instance.currentUser!.uid] =
            friendsMap.keys.cast<String>().toList();
      }
    });
  }

  Future<void> _sendFriendRequest(String friendUserId) async {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    await _friendRequestsReference
        .child(friendUserId)
        .child(currentUserId) // Add sender UID to the receiver's friend requests
        .set(true);

    // You might want to update your UI or show a message here.
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Friends'),
        actions: [
          IconButton(
            icon: Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendRequestsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _usersList.length,
        itemBuilder: (context, index) {
          final user = _usersList[index];
          return Card(
            elevation: 2.0,
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundImage: NetworkImage(
                    user.profilePictureUrl ?? 'URL_TO_DEFAULT_IMAGE'),
              ),
              title: Text(user.name),
              subtitle: Text(user.bio ?? 'No bio available'),
              trailing: ElevatedButton(
                onPressed: () {
                  _sendFriendRequest(user.uid);
                },
                child: Text('Send Request'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class UserProfileScreen extends StatelessWidget {
  final AddFriendUserData user;

  UserProfileScreen(this.user);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 2.0,
              margin: EdgeInsets.only(bottom: 16.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(
                    user.profilePictureUrl ?? 'URL_TO_DEFAULT_IMAGE'),
                radius: 50,
              ),
            ),
            Text(
              user.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Email: ${user.email}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 2.0,
              margin: EdgeInsets.only(top: 16.0),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio:',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      user.bio ?? 'No bio available',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestsScreen extends StatefulWidget {
  @override
  _FriendRequestsScreenState createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final DatabaseReference _friendRequestsReference =
  FirebaseDatabase.instance.reference().child('friend_requests');

  List<String> _friendRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
  }

  void _fetchFriendRequests() {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    _friendRequestsReference
        .child(currentUserId)
        .onValue
        .listen((event) {
      final requestsMap = event.snapshot.value as Map;
      final List<String> requests = [];

      if (requestsMap != null) {
        requestsMap.forEach((key, value) {
          requests.add(key);
        });
      }

      setState(() {
        _friendRequests = requests;
      });
    });
  }

  void _respondToRequest(String friendUserId, bool accept) async {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (accept) {
      // Add the friend to the user's friend list
      await FirebaseDatabase.instance
          .reference()
          .child('friends')
          .child(currentUserId)
          .child(friendUserId)
          .set(true);

      // Add the user to the friend's friend list
      await FirebaseDatabase.instance
          .reference()
          .child('friends')
          .child(friendUserId)
          .child(currentUserId)
          .set(true);
    }

    // Remove the friend request
    await _friendRequestsReference
        .child(currentUserId)
        .child(friendUserId)
        .remove();

    // You can update the UI or show a message here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friend Requests'),
      ),
      body: ListView.builder(
        itemCount: _friendRequests.length,
        itemBuilder: (context, index) {
          final friendUserId = _friendRequests[index];
          // Fetch user details based on friendUserId
          // You can use this information to display the user's name, profile picture, etc.
          // You may want to use FutureBuilder or another way to fetch this data.

          return ListTile(
            // Display user details here
            title: Text('Friend Request from $friendUserId'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () {
                    _respondToRequest(friendUserId, true);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    _respondToRequest(friendUserId, false);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddFriendUserData {
  final String uid;
  final String name;
  final String email;
  final bool isFriend;
  final String? profilePictureUrl;
  final String? bio;

  AddFriendUserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.isFriend,
    this.profilePictureUrl,
    this.bio,
  });

  factory AddFriendUserData.fromMap(
      Map<dynamic, dynamic> map, String uid, bool isFriend) {
    return AddFriendUserData(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      isFriend: isFriend,
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'],
    );
  }

  AddFriendUserData copyWith({bool? isFriend, String? bio}) {
    return AddFriendUserData(
      uid: this.uid,
      name: this.name,
      email: this.email,
      isFriend: isFriend ?? this.isFriend,
      profilePictureUrl: this.profilePictureUrl,
      bio: bio ?? this.bio,
    );
  }
}