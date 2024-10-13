import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:soshonew/settings_screen.dart';

class Post {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final List<dynamic> upvotedUsers;
  final List<dynamic> viewedUsers;
  final Timestamp? timestamp; // Added timestamp field

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.upvotedUsers,
    required this.viewedUsers,
    this.timestamp, // Added timestamp field
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return Post(
      id: doc.id,
      title: data?['title'] ?? 'Untitled',
      content: data?['content'] ?? '',
      imageUrl: data?['imageUrl'],
      upvotedUsers: data?['upvotedUsers'] ?? [],
      viewedUsers: data?['viewedUsers'] ?? [],
      timestamp: data?['timestamp'], // Added timestamp field
    );
  }
}

class Comment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final List<dynamic> replies;

  Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.replies,
  });

  factory Comment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return Comment(
      id: doc.id,
      postId: data?['postId'] ?? '',
      content: data?['content'] ?? '',
      authorId: data?['authorId'] ?? '',
      replies: data?['replies'] ?? [],
    );
  }
}

class PostsScreen extends StatefulWidget {
  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = 'user_123'; // Replace with actual user ID

  Future<void> _toggleUpvote(String postId, List<dynamic> upvotedUsers) async {
    final DocumentReference postRef =
        _firestore.collection('posts').doc(postId);

    if (upvotedUsers.contains(currentUserId)) {
      await postRef.update({
        'upvotedUsers': FieldValue.arrayRemove([currentUserId]),
      });
    } else {
      await postRef.update({
        'upvotedUsers': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  Future<void> _trackPostView(String postId, List<dynamic> viewedUsers) async {
    final DocumentReference postRef =
        _firestore.collection('posts').doc(postId);

    if (!viewedUsers.contains(currentUserId)) {
      await postRef.update({
        'viewedUsers': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  Future<int> _getCommentCount(String postId) async {
    final commentsQuerySnapshot = await _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();

    return commentsQuerySnapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Home',
            style: TextStyle(
                color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: 'For you'),
              Tab(text: 'Following'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () {
                // Notifications action
              },
            ),
          ],
        ),
        body: StreamBuilder<List<Post>>(
          stream: _firestore
              .collection('posts')
              .orderBy('timestamp', descending: true) // Order by timestamp
              .snapshots()
              .map((snapshot) {
            return snapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No posts available'));
            }

            final posts = snapshot.data!;
            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final isUpvoted = post.upvotedUsers.contains(currentUserId);

                return FutureBuilder<int>(
                  future: _getCommentCount(post.id),
                  builder: (context, commentSnapshot) {
                    final commentCount = commentSnapshot.data ?? 0;

                    return ListTile(
                      leading: Icon(Icons.article, color: Colors.teal),
                      title: Text(post.title,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.timestamp != null)
                            Text(
                              // Format the timestamp to a readable format
                              '${(post.timestamp!.toDate()).toLocal()}',
                              style: TextStyle(color: Colors.grey),
                            ),
                          Text(
                              '• ${post.viewedUsers.length} views • ${post.upvotedUsers.length} upvotes'),
                          if (post.imageUrl != null)
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: EdgeInsets.only(top: 10),
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(post.imageUrl!),
                                  fit: BoxFit.cover,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isUpvoted
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_off_alt,
                                  color: isUpvoted ? Colors.blue : Colors.grey,
                                ),
                                onPressed: () =>
                                    _toggleUpvote(post.id, post.upvotedUsers),
                              ),
                              Text('${post.upvotedUsers.length} votes'),
                              IconButton(
                                icon: Icon(Icons.comment, color: Colors.grey),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CommentsScreen(postId: post.id),
                                    ),
                                  );
                                },
                              ),
                              Text('$commentCount comments'),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CommentsScreen(postId: post.id),
                                ),
                              );
                            },
                            child: Text('View Comments'),
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.more_vert),
                      onTap: () {
                        _trackPostView(post.id, post.viewedUsers);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailScreen(
                              title: post.title,
                              content: post.content,
                              imageUrl: post.imageUrl,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ComposePostScreen(),
              ),
            );
          },
          child: Icon(Icons.edit),
          backgroundColor: Colors.green,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, color: Colors.black),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search, color: Colors.black),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_outline, color: Colors.black),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings,
                  color: Colors.black), // Add settings icon here
              label: '',
            ),
          ],
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (index) {
            // Handle navigation based on the index
            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(), // Navigate to SettingsScreen
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class CommentsScreen extends StatefulWidget {
  final String postId;

  CommentsScreen({required this.postId});

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    await _firestore.collection('comments').add({
      'postId': widget.postId,
      'content': _commentController.text,
      'authorId': 'user_123', // Replace with actual user ID
      'replies': [],
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _firestore
                  .collection('comments')
                  .where('postId', isEqualTo: widget.postId)
                  .snapshots()
                  .map((snapshot) {
                return snapshot.docs
                    .map((doc) => Comment.fromDocument(doc))
                    .toList();
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No comments yet.'));
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];

                    return ListTile(
                      title: Text(comment.content),
                      subtitle: Text('By ${comment.authorId}'),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String? imageUrl;

  PostDetailScreen({required this.title, required this.content, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            SizedBox(height: 16),
            Text(content, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class ComposePostScreen extends StatefulWidget {
  @override
  _ComposePostScreenState createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  File? _image;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref().child('post_images/$fileName');

    await ref.putFile(_image!);
    return await ref.getDownloadURL();
  }

  Future<void> _createPost() async {
    final String? imageUrl = await _uploadImage();

    await _firestore.collection('posts').add({
      'title': _titleController.text,
      'content': _contentController.text,
      'imageUrl': imageUrl,
      'upvotedUsers': [],
      'viewedUsers': [],
      'timestamp': FieldValue.serverTimestamp(), // Added timestamp
    });

    _titleController.clear();
    _contentController.clear();
    setState(() {
      _image = null;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Compose Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(labelText: 'Content'),
              maxLines: 5,
            ),
            SizedBox(height: 16),
            if (_image != null)
              Image.file(
                _image!,
                height: 200,
                fit: BoxFit.cover,
              ),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createPost,
              child: Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: PostsScreen(),
  ));
}
