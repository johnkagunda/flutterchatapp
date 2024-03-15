import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chats.dart';
import 'post_details_screen.dart';

import 'settings_screen.dart';
class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}
class UserInfo {
  final String name;
  final String bio;

  UserInfo({required this.name, required this.bio});
}




class UserData {
  final String uid;
  final String name;
  final String email;
  final bool isFriend;
  final String? profilePictureUrl; // Nullable profile picture URL
  final String? bio; // Nullable bio

  UserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.isFriend,
    this.profilePictureUrl,
    this.bio,
  });

  factory UserData.fromMap(Map<dynamic, dynamic> map, String uid, bool isFriend) {
    return UserData(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      isFriend: isFriend,
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'], // Assuming 'bio' is the key in the map
    );
  }

  UserData copyWith({bool? isFriend, String? bio}) {
    return UserData(
      uid: this.uid,
      name: this.name,
      email: this.email,
      isFriend: isFriend ?? this.isFriend,
      profilePictureUrl: this.profilePictureUrl,
      bio: bio ?? this.bio,
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  PickedFile? _pickedFile;
  TextEditingController _bioController = TextEditingController();

  Future<void> _uploadProfilePictureAndBio() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Check if either the bio or profile picture is being updated
        if (_pickedFile != null || _bioController.text.isNotEmpty) {
          if (_pickedFile != null) {
            // Upload the image to Firebase Storage
            final storageRef = _storage.ref().child('profile_pictures/${user.uid}');
            await storageRef.putFile(File(_pickedFile!.path!));

            // Update the user's data with the profile picture URL
            await user.updateProfile(photoURL: await storageRef.getDownloadURL());

            // Update the profile picture URL in the database
            await FirebaseDatabase.instance
                .reference()
                .child('users')
                .child(user.uid)
                .update({'profilePictureUrl': user.photoURL});
          }

          // Update the user's bio in the database
          await FirebaseDatabase.instance
              .reference()
              .child('users')
              .child(user.uid)
              .update({'bio': _bioController.text});

          // Update the UI or show a success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile picture and bio uploaded successfully.'),
            ),
          );
        } else {
          // Handle the case when no changes are made
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No changes made.'),
            ),
          );
        }
      } else {
        // Handle the case when the user is not signed in
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not signed in.'),
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile picture and bio: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.getImage(source: ImageSource.gallery);

    setState(() {
      _pickedFile = pickedFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.indigo,
                    Colors.blue,
                    Colors.pink,
                    Colors.black,
                    Colors.white,
                  ],
                ),
              ),
            ),
            CircleAvatar(
              backgroundImage: _pickedFile != null
                  ? FileImage(File(_pickedFile!.path!)) as ImageProvider<Object>?
                  : NetworkImage(_auth.currentUser?.photoURL ?? 'URL_TO_DEFAULT_IMAGE') as ImageProvider<Object>?,
              radius: 80, // Adjust the radius to your desired size
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _bioController,
              decoration: InputDecoration(labelText: 'Enter Bio'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadProfilePictureAndBio,
              child: Text('Upload Profile Picture and Bio'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to UserProfileScreen and pass the user data
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfScreen(
                      user: UserData(
                        uid: _auth.currentUser?.uid ?? '',
                        name: _auth.currentUser?.displayName ?? '',
                        email: _auth.currentUser?.email ?? '',
                        isFriend: false,
                        profilePictureUrl: _auth.currentUser?.photoURL ?? 'URL_TO_DEFAULT_IMAGE',
                        bio: _bioController.text,
                      ),
                    ),
                  ),
                );
              },
              child: Text('View Details'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    // Navigate to the SettingsScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                  tooltip: 'Settings',
                ),
                Text('Settings'),
                IconButton(
                  icon: Icon(Icons.explore),  // Replace with the appropriate icon for chats
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PostsScreen ()),
                    );
                  },
                ),
              ],
            ),




          ],
        ),
      ),
    );
  }
}

class UserProfScreen extends StatefulWidget {
  final UserData user;

  UserProfScreen({required this.user});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfScreen> {
  String? _bio = 'Loading bio...';

  @override
  void initState() {
    super.initState();
    _fetchBio();
  }

  Future<void> _fetchBio() async {
    try {
      // Fetch the bio from the database based on the user's UID
      DatabaseEvent bioEvent = await FirebaseDatabase.instance
          .reference()
          .child('users')
          .child(widget.user.uid)
          .child('bio')
          .once();

      _bio = bioEvent.snapshot.value as String?;
      if (_bio == null) {
        _bio = 'No bio available';
      }

      setState(() {});
    } catch (error) {
      print('Error fetching bio: $error');
      _bio = 'Error fetching bio';
      setState(() {});
    }
  }

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
            CircleAvatar(
              backgroundImage: NetworkImage(widget.user.profilePictureUrl ?? 'URL_TO_DEFAULT_IMAGE'),
              radius: 50,
            ),
            SizedBox(height: 20),
            Text(
              widget.user.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              widget.user.email,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bio:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _bio!,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  void _pickImage() async {
    final pickedFile =
    await ImagePicker().getImage(source: ImageSource.gallery);
    setState(() {
      _pickedImage = pickedFile;
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
        (selectedPaymentType == 'All' || post.paymentType == selectedPaymentType) &&
        post.uid == _currentUser?.uid)  // Add this condition to filter by current user
        .toList();
  }

  List<Post> get filteredAndSearchedPosts {
    return filteredPosts.where((post) {
      final lowerSearchText = searchText.toLowerCase();
      return (post.category.toLowerCase().contains(lowerSearchText) ||
          post.content.toLowerCase().contains(lowerSearchText)) &&
          post.uid == _currentUser?.uid;  // Add this condition to filter by current user
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
            : Text(''),
        actions: <Widget>[


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
              icon: Icon(Icons.edit),
              onPressed: () {
                _showPostContentDialog();
              },
            ),




          ],
        ),
      )
          : null,
    );
  }

  void _showPostContentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Compose a Post'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _postController,
                  decoration: InputDecoration(labelText: 'Write your post'),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                ),
                TextField(
                  controller: _moreDetailsController,
                  decoration: InputDecoration(labelText: 'More Details'),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_a_photo),
                      onPressed: _pickImage,
                    ),
                    Text('Add Photo'),
                  ],
                ),
                Text('Select Event Type:'),
                DropdownButton<String>(
                  value: selectedEventType,
                  items: eventTypes.map((String eventType) {
                    return DropdownMenuItem<String>(
                      value: eventType,
                      child: Text(eventType),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      selectedEventType = value ?? 'All';
                    });
                  },
                ),
                SizedBox(height: 16),
                Text('Select Category:'),
                DropdownButton<String>(
                  value: selectedCategory,
                  items: categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      selectedCategory = value ?? 'All';
                    });
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Post'),
              onPressed: () {
                Navigator.of(context).pop();
                _postTweet();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEventSelectionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Select Event Type and Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event Type:'),
                  DropdownButton<String>(
                    value: selectedEventType,
                    items: eventTypes.map((String eventType) {
                      return DropdownMenuItem<String>(
                        value: eventType,
                        child: Text(eventType),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedEventType = value ?? 'All';
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Text('Category:'),
                  DropdownButton<String>(
                    value: selectedCategory,
                    items: categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedCategory = value ?? 'All';
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Text('Selected Event Type: $selectedEventType'),
                  Text('Selected Category: $selectedCategory'),
                ],
              ),
            );
          },
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



  void _showMoreDetails(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(content: post.moreDetails),
      ),
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
