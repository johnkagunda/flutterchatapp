import 'package:flutter/material.dart';

class AttendeesScreen extends StatefulWidget {
  final String postId;
  final Future<Map<String, String>> Function(String) fetchUserData;

  AttendeesScreen({required this.postId, required this.fetchUserData});

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
    // Fetch the list of user UIDs attending the event
    // Example: List<String> attendingUserUids = await fetchAttendeesFromDatabase();

    List<String> attendingUserUids = ['userUid1', 'userUid2', 'userUid3'];

    // Fetch the user data for each attending user using the fetchUserData function
    List<Future<Map<String, String>>> fetchUserDataFutures = attendingUserUids.map(widget.fetchUserData).toList();

    // Wait for all fetchUserDataFutures to complete and update the state with the user data
    List<Map<String, String>> userDataList = await Future.wait(fetchUserDataFutures);

    // Update the state with the fetched user data
    setState(() {
      attendeesData = userDataList;
    });
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
            title: Text('$name ($uid)'),
            // You can customize the ListTile as needed
          );
        },
      ),
    );
  }
}
