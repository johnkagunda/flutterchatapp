import 'dart:io';
import 'package:SoshoBird/addfriend.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_screen.dart';
import 'post_details_screen.dart';

import 'chats.dart';


import 'profile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppAndDatabase();
  runApp(MyApp());
}

void initializeAppAndDatabase() async {
  await Firebase.initializeApp();
  FirebaseDatabase.instance.setPersistenceEnabled(true);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthScreen(),
    );
  }
}

class PostsScreen extends StatefulWidget {
  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  DatabaseReference? _databaseReference;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _moreDetailsController = TextEditingController();
  User? _currentUser;
  PickedFile? _pickedImage;
  String searchText = '';
  bool isSearching = false;
  String selectedCategory = 'All';
  String selectedEventType = 'All';
  String selectedPaymentType = 'All';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _databaseReference = FirebaseDatabase.instance.reference().child('posts');

    if (_currentUser != null) {
      _fetchUsers();
    }
  }

  final List<Post> _posts = [];

  void _fetchUsers() {
    DatabaseReference usersReference =
    FirebaseDatabase.instance.reference().child('users');

    usersReference.onValue.listen((event) async {
      final usersMap = event.snapshot.value as Map;
      final Map<String, String> userNames = {};

      if (usersMap != null) {
        usersMap.forEach((key, value) {
          if (value is Map && value.containsKey('name')) {
            userNames[key] = value['name'];
          }
        });
      }

      _databaseReference!.onChildAdded.listen((event) async {
        final postMap = event.snapshot.value as Map;

        final String uid = postMap['uid'];
        final String userName = userNames[uid] ?? "Anonymous";

        setState(() {
          _posts.add(
            Post.fromMap(
              postMap,
              event.snapshot.key ?? '',
              userName,
            ),
          );
        });
      });
    });
  }



  void _postTweet() async {
    final String postContent = _postController.text.trim();
    final String moreDetails = _moreDetailsController.text.trim();
    if (postContent.isNotEmpty &&
        _currentUser != null &&
        _databaseReference != null &&
        selectedCategory != 'All' &&
        selectedEventType != 'All') {
      String downloadURL = "";

      if (_pickedImage != null) {
        Reference ref =
        FirebaseStorage.instance.ref().child("images/${DateTime.now()}.jpg");
        await ref.putFile(File(_pickedImage!.path));
        downloadURL = await ref.getDownloadURL();
      }

      final newPost = Post(
        key: _databaseReference!.push().key ?? '',
        uid: _currentUser!.uid,
        name: _currentUser!.displayName ?? "Anonymous",
        content: postContent,
        pictureURL: downloadURL,
        category: selectedCategory,
        eventType: selectedEventType,
        paymentType: selectedPaymentType,
        moreDetails: moreDetails,
      );

      _databaseReference!.child(newPost.key).set(newPost.toMap());
      _postController.clear();
      _moreDetailsController.clear();
      setState(() {
        _pickedImage = null;
        selectedCategory = 'All';
        selectedEventType = 'All';
      });
    } else {
      // Display an error message or take appropriate action if fields are not filled
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select event type and category.'),
        ),
      );
    }
  }

  List<String> categories = [
    'All',
    'Business & Professional',
    'Arts & Entertainment',
    'Health & Wellness',
    'Science & Technology',
    'Food & Drink',
    'Sports & Fitness',
    'Music',
    'Family & Education',
    'Community & Culture',
    'Charity & Causes',
  ];

  List<String> eventTypes = [
    'All',
    'Conference',
    'Seminar',
    'Workshop',
    'Expo/Exhibition',
    'Trade Show',
    'Festival',
    'Concert',
    'Webinar',
    'Meetup',
    'Networking Event',
  ];

  List<String> paymentTypes = ['All', 'Free', 'Paid'];


  List<Post> get filteredPosts {
    return _posts
        .where((post) =>
    (selectedCategory == 'All' || post.category == selectedCategory) &&
        (selectedEventType == 'All' || post.eventType == selectedEventType) &&
        (selectedPaymentType == 'All' || post.paymentType == selectedPaymentType))
        .toList();
  }

  List<Post> get filteredAndSearchedPosts {
    return filteredPosts.where((post) {
      final lowerSearchText = searchText.toLowerCase();
      return post.category.toLowerCase().contains(lowerSearchText) ||
          post.content.toLowerCase().contains(lowerSearchText);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  isSearching = false;
                  searchText = '';
                });
              },
            ),

            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        )
            : Text('SOSHOBIRDY'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                searchText = '';
              });
            },
          ),
          if (FirebaseAuth.instance.currentUser == null)
            LoginOrRegisterButton(), // Display only if the user is not logged in

        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display events by category
          if (selectedCategory != 'All')
            Text(
              'Events in $selectedCategory Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: isSearching
                  ? filteredAndSearchedPosts.length
                  : filteredPosts.length,
              itemBuilder: (context, index) {
                final post = isSearching
                    ? filteredAndSearchedPosts[
                filteredAndSearchedPosts.length - 1 - index]
                    : filteredPosts[filteredPosts.length - 1 - index];

                return GestureDetector(
                  onTap: () {
                    _showMoreDetails(post);
                  },
                  child: PostWidget(
                    post: post,
                    databaseReference: _databaseReference!,
                  ),
                );
              },
            ),
          ),

          if (_pickedImage != null) Image.file(File(_pickedImage!.path)),
        ],
      ),
      bottomNavigationBar: FirebaseAuth.instance.currentUser != null
          ? BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home),  // Use the home icon
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostsScreen()),
                );
              },
            ),

            IconButton(
              icon: Icon(Icons.chat),
              onPressed: () {
                if (FirebaseAuth.instance.currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatsScreen()),
                  );
                } else {
                  _showLoginAlert(context);
                }
              },
            ),

            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                if (FirebaseAuth.instance.currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddFriendScreen()),
                  );
                } else {
                  _showLoginAlert(context);
                }
              },
            ),





            IconButton(
              icon: Icon(Icons.person),  // Replace with the appropriate icon for profile
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),

          ],
        ),
      )
          : null,
    );
  }

  void _showLoginAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Please Login First'),
          content: Text('You need to log in to perform this action.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCategorySelectionDialog(BuildContext context) async {
    String selectedCategory = 'All';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select a Category'),
          content: Column(
            children: [
              for (String category in categories)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = category;
                    });
                    Navigator.pop(context, selectedCategory);
                  },
                  child: Text(category),
                ),
            ],
          ),
        );
      },
    );

    // Update posts based on the selected category
    setState(() {
      selectedCategory = selectedCategory;
    });
  }

  Future<void> _showEventTypeSelectionDialog(BuildContext context) async {
    String selectedEventType = 'All';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select an Event Type'),
          content: Column(
            children: [
              for (String eventType in eventTypes)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedEventType = eventType;
                    });
                    Navigator.pop(context, selectedEventType);
                  },
                  child: Text(eventType),
                ),
            ],
          ),
        );
      },
    );

    // Update posts based on the selected event type
    setState(() {
      selectedEventType = selectedEventType;
    });
  }

  void _showMoreDetails(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(content: post.moreDetails),
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.login),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AuthScreen()),
        );
      },
    );
  }
}

class Post {
  final String key;
  final String uid;
  final String name;
  final String content;
  final String? pictureURL;
  final String category;
  final String eventType;
  final String paymentType;
  final String moreDetails;


  Post({
    required this.key,
    required this.uid,
    required this.name,
    required this.content,
    this.pictureURL,
    required this.category,
    required this.eventType,
    required this.paymentType,
    required this.moreDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'content': content,
      'pictureURL': pictureURL,
      'category': category,
      'eventType': eventType,
      'paymentType': paymentType,
      'moreDetails': moreDetails,
    };
  }

  factory Post.fromMap(
      Map<dynamic, dynamic> map, String key, String userName) {
    return Post(
      key: key,
      uid: map['uid'],
      name: userName,
      content: map['content'],
      pictureURL: map['pictureURL'],
      category: map['category'] ?? '',
      eventType: map['eventType'] ?? '',
      paymentType: map['paymentType'] ?? '',
      moreDetails: map['moreDetails'] ?? '',
    );
  }
}

class PostWidget extends StatelessWidget {
  final Post post;
  final DatabaseReference databaseReference;

  PostWidget({
    required this.post,
    required this.databaseReference,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              post.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(post.content),
              ),
            if (post.pictureURL != null)
              SizedBox(
                height: 200,
                child: Image.network(post.pictureURL!),
              ),
          ],
        ),
      ),
    );
  }
}

class LoginOrRegisterButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasData) {
          return SizedBox.shrink();
        } else {
          return Container(
            color: Colors.black,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AuthScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue,
                ),
                child: Text(
                  'Log In or Sign Up',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
