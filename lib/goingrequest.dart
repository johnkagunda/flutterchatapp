import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'posts.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

void initializeAppAndDatabase() async {
  await Firebase.initializeApp();
  FirebaseDatabase.instance.setPersistenceEnabled(true);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    initializeAppAndDatabase();
    return MaterialApp(
      home: GoingRequestsScreen(),
    );
  }
}

class Request {
  final String senderName;

  Request({required this.senderName});
}

class GoingRequestsScreen extends StatefulWidget {
  @override
  _GoingRequestsScreenState createState() => _GoingRequestsScreenState();
}

class _GoingRequestsScreenState extends State<GoingRequestsScreen> {
  final List<Request> requests = [];

  @override
  void initState() {
    super.initState();
    fetchGoingRequests();
  }

  void fetchGoingRequests() {
    // Assuming 'going_requests' is a node in your Realtime Database
    DatabaseReference goingRequestsReference =
    FirebaseDatabase.instance.reference().child('going_requests');

    FirebaseAuth auth = FirebaseAuth.instance;
    User? currentUser = auth.currentUser;

    if (currentUser != null) {
      goingRequestsReference.child(currentUser.uid).onValue.listen((event) {
        final requestsMap = event.snapshot.value as Map;

        if (requestsMap != null) {
          setState(() {
            requests.clear();
            requests.addAll(requestsMap.entries
                .where((entry) => entry.value == true)
                .map((entry) => Request(senderName: entry.key))
                .toList());
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Going Requests'),
      ),
      body: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return ListTile(
            title: Text(request.senderName),
            subtitle: Text('Sent you a going request'),
          );
        },
      ),
    );
  }
}
