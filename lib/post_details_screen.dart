import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PostDetailsScreen extends StatefulWidget {
  final String content;
  final String postId;

  PostDetailsScreen({required this.content, this.postId = ''});

  @override
  _PostDetailsScreenState createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  bool isAttending = false;
  String? userUid;
  String? userName;

  @override
  void initState() {
    super.initState();
    // Fetch user information when the widget is initialized
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userUid = user.uid;
        userName = user.displayName ?? '';
      });
    }
  }

  Future<void> toggleAttendance() async {
    // Ensure user info is fetched before proceeding
    if (userUid != null && userName != null) {
      // Reference to the 'going' node in the Realtime Database
      DatabaseReference goingRef =
      FirebaseDatabase.instance.reference().child('events/${widget.postId}/going');

      if (!isAttending) {
        // If not already attending, set the value to true or any relevant data
        await goingRef.child(userUid!).set({
          'uid': userUid,
          'name': userName,
        });
      } else {
        // If already attending, remove the user from the 'going' list
        await goingRef.child(userUid!).remove();
      }

      // Update the state to reflect the current attendance status
      setState(() {
        isAttending = !isAttending;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post Details'),
        actions: [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More Details:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.content,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: toggleAttendance,
              child: Text(isAttending ? 'Going' : 'RSVP'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendeesScreen(
                      postId: widget.postId,
                    ),
                  ),
                );
              },
              child: Text('View Attendees of the event'),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendeesScreen extends StatefulWidget {
  final String postId;

  AttendeesScreen({required this.postId});

  @override
  _AttendeesScreenState createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen> {
  List<Map<String, String>> attendeesData = [];

  @override
  void initState() {
    super.initState();
    // Load attendees when the widget is initialized
    loadAttendees();
  }

  Future<void> loadAttendees() async {
    DatabaseReference goingRef =
    FirebaseDatabase.instance.reference().child('events/${widget.postId}/going');

    try {
      // Fetch the snapshot asynchronously
      DatabaseEvent event = await goingRef.once();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<dynamic, dynamic> attendeesMap = snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, String>> userDataList = [];

        // Fetch user data for each attendee
        attendeesMap.forEach((key, value) {
          // Access user data from the value map
          String uid = key;
          String name = value['name'];

          userDataList.add({'uid': uid, 'name': name});
        });

        setState(() {
          attendeesData = userDataList;
        });
      }
    } catch (error) {
      // Handle any errors that occur during data fetching
      print('Error fetching attendees: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendees'),
      ),
      body: ListView.builder(
        itemCount: attendeesData.length,
        itemBuilder: (context, index) {
          // Access UID and Name from the user data map
          String uid = attendeesData[index]['uid'] ?? '';
          String name = attendeesData[index]['name'] ?? '';

          return ListTile(
            title: Text('$name'),
            subtitle: Text('UID: $uid'),
            // You can customize the ListTile as needed
          );
        },
      ),
    );
  }
}
