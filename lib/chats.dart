import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'addfriend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    home: ChatsScreen(),
    builder: (context, child) {
      return ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: child!,
      );
    },
  ));
}





class MyCustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlidePageRoute({required this.page})
      : super(
    pageBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: curve),
      );

      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}






class ChatsScreen extends StatefulWidget {
  @override
  _ChatsScreenState createState() => _ChatsScreenState();

}

class _ChatsScreenState extends State<ChatsScreen> {
  int _currentIndex = 0;

  final DatabaseReference _databaseReference =
  FirebaseDatabase.instance.reference().child('users');
  final List<UserInfo> _users = [];
  final Map<String, List<Message>> _userMessages = {};
  late User _currentUser;
  List<UserInfo> _filteredUsers = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _fetchUsers();
  }

  void _fetchUsers() {
    DatabaseReference friendsReference = FirebaseDatabase.instance
        .reference()
        .child('friends')
        .child(_currentUser.uid);

    friendsReference.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final friendUids = List<String>.from(data.keys);

        _databaseReference.onValue.listen((event) {
          final data = event.snapshot.value;
          if (data != null && data is Map) {
            final userList = data.entries
                .map((entry) => UserInfo.fromMap(entry.key, entry.value))
                .where((user) =>
            user.uid != _currentUser.uid &&
                friendUids.contains(user.uid))
                .toList();

            for (final user in userList) {
              final chatId =
              ChatScreen.getChatId(_currentUser.uid, user.uid);
              final unreadMessagesExist =
                  _userMessages[chatId]?.any((message) => !message.isRead) ??
                      false;

              user.isUnread = unreadMessagesExist;
              if (unreadMessagesExist) {
                _fetchRecentMessages(chatId);
              }
            }

            userList.sort((a, b) {
              final aTimestamp =
                  _userMessages[ChatScreen.getChatId(_currentUser.uid, a.uid)]
                      ?.first?.timestamp ??
                      DateTime(1970);
              final bTimestamp =
                  _userMessages[ChatScreen.getChatId(_currentUser.uid, b.uid)]
                      ?.first?.timestamp ??
                      DateTime(1970);

              return bTimestamp.compareTo(aTimestamp);
            });

            setState(() {
              _users.clear();
              _users.addAll(userList);
              _filteredUsers = List.from(_users);
            });
          }
        });
      }
    });
  }

  void _unfriendUser(UserInfo user, User currentUser) {
    final friendUid = user.uid;

    // Reference to the "friends" node for the current user
    DatabaseReference currentUserFriendsRef = FirebaseDatabase.instance
        .reference()
        .child('friends')
        .child(currentUser.uid);

    // Reference to the "friends" node for the friend to be unfriended
    DatabaseReference friendFriendsRef = FirebaseDatabase.instance
        .reference()
        .child('friends')
        .child(friendUid);

    // Remove the friend from the current user's friends list
    currentUserFriendsRef.child(friendUid).remove().then((_) {
      // Remove the current user from the friend's friends list
      friendFriendsRef.child(currentUser.uid).remove().then((_) {
        // Fetch the updated list of users after unfriending
        _fetchUsers();
      }).catchError((error) {
        print('Error removing current user from friend\'s friends list: $error');
      });
    }).catchError((error) {
      print('Error removing friend from current user\'s friends list: $error');
    });
  }

  void _showUnfriendConfirmationDialog(UserInfo user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Unfriend Confirmation'),
          content: Text('Are you sure you want to unfriend ${user.name}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unfriendUser(user, _currentUser);
              },
              child: Text('Unfriend'),
            ),
          ],
        );
      },
    );
  }


  void _fetchRecentMessages(String chatId) {
    final messagesReference = FirebaseDatabase.instance
        .reference()
        .child('messages')
        .child('private_chats')
        .child(chatId);

    messagesReference.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final messages = data.entries
            .map((entry) => Message.fromMap(entry.key, entry.value))
            .toList();

        setState(() {
          _userMessages[chatId] = messages;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '',
          style: TextStyle(color: Color(0xFF128C7E)),
        ),
        backgroundColor: Colors.black,
        actions: [],
      ),
      body: ListView.builder(
        itemCount: _filteredUsers.length > 0 ? _filteredUsers.length : 1,
        itemBuilder: (context, index) {
          if (_filteredUsers.isEmpty) {
            return ListTile(
              title: Text(
                'Add friends in the icon above',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            );
          }

          final user = _filteredUsers[index];
          final isUnread = user.isUnread;
          final lastMessage =
              _userMessages[ChatScreen.getChatId(_currentUser.uid, user.uid)]
                  ?.first;

          return Container(
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
              color: Colors.white,
              boxShadow: [
              BoxShadow(
              color: Colors.grey.withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: Offset(0, 2),
          ),
          ],
          ),
          child: ListTile(
          contentPadding: EdgeInsets.all(16),
          title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          GestureDetector(
          onLongPress: () {
          _showUnfriendConfirmationDialog(user);
          },
          child: Row(
          children: [
          CircleAvatar(
          backgroundImage: user.profilePictureUrl != null
          ? NetworkImage(user.profilePictureUrl!) as ImageProvider<Object>?
              : AssetImage('assets/default_profile_picture.png') as ImageProvider<Object>?,
          radius: 20,
          ),
          SizedBox(width: 8),
          Text(
          user.name,
          style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add other elements in the row if needed
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add other subtitle elements if needed
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle),
                  color: Colors.red,
                  onPressed: () {
                    _unfriendUser(user, _currentUser);
                  },
                ),
                if (user.isUnread)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'New',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              _startPrivateChat(context, user);
            },
          ),
          );
        },
      ),
    );
  }


  void _startPrivateChat(BuildContext context, UserInfo user) {
    final chatId =
    ChatScreen.getChatId(_currentUser.uid, user.uid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          user: user,
          currentUser: _currentUser,
          messages: _userMessages.containsKey(chatId)
              ? _userMessages[chatId]!
              : [],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      final format = DateFormat('MMM d');
      return format.format(timestamp);
    }
  }
}






  @override

  @override


String _formatMessageTime(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  } else {
    final format = DateFormat('MMM d');
    return format.format(timestamp);
  }
}

class UserInfo {
  final String uid;
  final String name;
  final String email;
  bool isUnread;
  DateTime lastOnline;
  final String? profilePictureUrl;
  final String? bio; // New property

  UserInfo({
    required this.uid,
    required this.name,
    required this.email,
    this.isUnread = false,
    DateTime? lastOnline,
    this.profilePictureUrl,
    this.bio, // New property with default value
  }) : lastOnline = lastOnline ?? DateTime.fromMillisecondsSinceEpoch(0);

  String get lastSeenDisplay {
    final now = DateTime.now();
    final difference = now.difference(lastOnline);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      final format = DateFormat('MMM d');
      return format.format(lastOnline);
    }
  }

  bool get isOnline {
    // Use a timestamp comparison to determine if the user is online
    final now = DateTime.now();
    final difference = now.difference(lastOnline);
    return difference.inMinutes < 5; // Consider online if last seen within the last 5 minutes
  }

  factory UserInfo.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserInfo(
      uid: uid,
      name: map['name'],
      email: map['email'],
      lastOnline: DateTime.fromMillisecondsSinceEpoch(map['lastOnline'] ?? 0),
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'], // Assign the value from the map to the new property
    );
  }
}


class ChatScreen extends StatefulWidget {
  final UserInfo user;
  final User currentUser;
  final DatabaseReference _messagesReference;
  final List<Message> messages;

  ChatScreen({
    required this.user,
    required this.currentUser,
    required this.messages,
  }) : _messagesReference = FirebaseDatabase.instance
      .reference()
      .child('messages')
      .child('private_chats')
      .child(getChatId(currentUser.uid, user.uid));

  @override
  _ChatScreenState createState() => _ChatScreenState();

  static String getChatId(String user1, String user2) {
    final users = [user1, user2]..sort();
    return '${users[0]}_${users[1]}';
  }
}

class Message {
  final String senderUid;
  final String text;
  final DateTime timestamp;
  bool isRead;
  String key;
  Message? replyMessage;
  Map<String, String> reactions;
  List<String> reactedUsers; // Add a property to store users who reacted

  Message({
    required this.senderUid,
    required this.text,
    required this.timestamp,
    required this.key,
    this.isRead = false,
    this.replyMessage,
    required this.reactions,
    required this.reactedUsers,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'senderUid': senderUid,
      'text': text,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'isRead': isRead,
      'reactions': reactions,
      'reactedUsers': reactedUsers, // Include reacted users in the map
    };

    if (replyMessage != null) {
      map['replyMessage'] = {
        'senderUid': replyMessage!.senderUid,
        'text': replyMessage!.text,
        'timestamp': replyMessage!.timestamp.toUtc().toIso8601String(),
        'isRead': replyMessage!.isRead,
      };
    }

    return map;
  }

  static Message fromMap(String key, Map<dynamic, dynamic> map) {
    return Message(
      senderUid: map['senderUid'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
      key: key,
      isRead: map['isRead'],
      replyMessage: map['replyMessage'] != null
          ? Message.fromMap('', map['replyMessage'])
          : null,
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      reactedUsers: List<String>.from(map['reactedUsers'] ?? []),
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  Message? _selectedMessageForReply;
  List<String> _reactions = ['😊', '❤️', '😢', '😮', '👍', '👎'];
  String? _selectedReaction;

  @override

  void _loadMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    widget._messagesReference.onChildAdded.listen((event) {
      final messageMap = event.snapshot.value as Map;
      final message = Message.fromMap(
        event.snapshot.key ?? '',
        messageMap,
      );

      if (!widget.messages.any((existingMessage) => existingMessage.key == message.key)) {
        if (message.senderUid != widget.currentUser.uid && !message.isRead) {
          _markAsRead(message);
        }

        setState(() {
          widget.messages.insert(0, message);
        });

        // Save messages to SharedPreferences
        List<String> messagesJson = prefs.getStringList('messages') ?? [];
        messagesJson.add(json.encode(message.toMap()));
        prefs.setStringList('messages', messagesJson);
      }
    });
  }
  void _markAsRead(Message message) {
    final readRef = widget._messagesReference.child(message.key).child('isRead');
    readRef.set(true);

    setState(() {
      message.isRead = true;
    });
  }

  void _deleteMessage(Message message) {
    final messageRef = widget._messagesReference.child(message.key);

    messageRef.remove().then((_) {
      setState(() {
        widget.messages.remove(message);
      });
    }).catchError((error) {
      print('Error deleting message: $error');
    });
  }

  AddFriendUserData convertUserInfoToUserData(UserInfo userInfo) {
    // Implement the conversion logic here
    return AddFriendUserData(
      uid: userInfo.uid,
      name: userInfo.name,
      email: userInfo.email,
      isFriend: false,  // You may set the initial value as needed
      profilePictureUrl: userInfo.profilePictureUrl,
      bio: userInfo.bio ?? 'No bio available',  // Set to a default value or 'No bio available'
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Assuming widget.user is of type UserInfo
            AddFriendUserData userData = convertUserInfoToUserData(widget.user);

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserProfileScreen(userData)),
            );
          },
          child: Text(widget.user.name),
        ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () {
              // Implement video call functionality
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'userProfile') {
                // Assuming widget.user is of type UserInfo
                AddFriendUserData userData = convertUserInfoToUserData(widget.user);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfileScreen(userData)),
                );
              }
              // Add more options as needed
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'userProfile',
                child: Text('User Profile'),
              ),
              // Add more menu items as needed
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedMessageForReply != null)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.grey.withOpacity(0.3),
              child: ListTile(
                title: Text(
                  'Replying to: ${_selectedMessageForReply!.text}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedMessageForReply = null;
                      _messageController.clear();
                    });
                  },
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isCurrentUser = message.senderUid == widget.currentUser.uid;

                return GestureDetector(
                  onLongPress: () {
                    // Existing long press logic...
                  },
                  child: Dismissible(
                    key: Key(message.key),
                    onDismissed: (direction) {
                      setState(() {
                        _selectedMessageForReply = message;
                        _messageController.text = '';
                      });
                    },
                    background: Container(
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    child: Container(
                      margin: EdgeInsets.only(
                          top: 8,
                          right: isCurrentUser ? 8 : 16,
                          left: isCurrentUser ? 16 : 8,
                          bottom: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCurrentUser ? Color(0xFFFFC0CB) : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isCurrentUser ? 16 : 4),
                          topRight: Radius.circular(isCurrentUser ? 4 : 16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        children: [
                          ListTile(
                            title: Row(
                              children: [
                                Text(
                                  isCurrentUser ? 'You' : widget.user.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentUser ? Colors.black : Colors.black,
                                  ),
                                ),
                                if (message.isRead && isCurrentUser)
                                  Icon(
                                    Icons.done_all,
                                    color: isCurrentUser ? Colors.black : Color(0xFF128C7E),
                                    size: 18,
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isCurrentUser ? Colors.black : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatMessageTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (message.reactions.isNotEmpty)
                                  Row(
                                    children: message.reactions.entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          '${entry.value} ',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                if (message.replyMessage != null)
                                  Container(
                                    color: Colors.grey.withOpacity(0.3),
                                    padding: EdgeInsets.all(8),
                                    child: ListTile(
                                      title: Text(
                                        'Replied to: ${message.replyMessage!.text}',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(Icons.close),
                                        onPressed: () {
                                          setState(() {
                                            _selectedMessageForReply = null;
                                            _messageController.clear();
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: SizedBox.shrink(),
                            onTap: () {
                              // Handle normal tap, e.g., mark as read or navigate to details
                            },
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.favorite),
                                  onPressed: () {
                                    _showReactionsDialog(context, message);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.visibility),
                                  onPressed: () {
                                    _showInsight(message);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedMessageForReply != null)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.grey.withOpacity(0.3),
              child: ListTile(
                title: Text(
                  'Replying to: ${_selectedMessageForReply!.text}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedMessageForReply = null;
                      _messageController.clear();
                    });
                  },
                ),
              ),
            ),
          Container(
            color: Colors.grey.withOpacity(0.3),
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      contentPadding:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _sendMessage();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionsDialog(BuildContext context, Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select a Reaction'),
          content: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _reactions
                .map((reaction) => GestureDetector(
              onTap: () {
                _reactToMessage(message, reaction);
                Navigator.pop(context);
              },
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  reaction,
                  style: TextStyle(
                    fontSize: 20.0,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
        );
      },
    );
  }

  void _reactToMessage(Message message, String reaction) {
    final reactionRef = widget._messagesReference
        .child(message.key)
        .child('reactions')
        .child(widget.currentUser.uid);

    // Check if the current user already reacted
    if (message.reactions.containsKey(widget.currentUser.uid)) {
      // If already reacted, remove the reaction
      reactionRef.remove();
      setState(() {
        message.reactions.remove(widget.currentUser.uid);
        message.reactedUsers.remove(widget.currentUser.uid);
        _selectedReaction = null;
      });
    } else {
      // If not reacted, set the reaction
      reactionRef.set(reaction);

      setState(() {
        message.reactions[widget.currentUser.uid] = reaction;
        message.reactedUsers.add(widget.currentUser.uid);
        _selectedReaction = reaction;
      });
    }
  }


  void _sendMessage() {
    final String messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      final message = Message(
        senderUid: widget.currentUser.uid,
        text: messageText,
        timestamp: DateTime.now(),
        key: '',
        isRead: false,
        reactions: {},
        reactedUsers: [], // Add an empty list for reacted users
      );

      if (_selectedMessageForReply != null) {
        message.replyMessage = _selectedMessageForReply;
      }

      final newMessageRef = widget._messagesReference.push();
      message.key = newMessageRef.key!;

      newMessageRef.set(message.toMap());

      setState(() {
        widget.messages.insert(0, message);
        _selectedMessageForReply = null;
      });

      _messageController.clear();
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      final format = DateFormat('MMM d');
      return format.format(timestamp);
    }
  }

  void _showInsight(Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, String>>(
          future: _fetchReactionsAndUsers(message),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              Map<String, String> usersWithReactions = snapshot.data!;

              return AlertDialog(
                title: Text('Reactions Insight'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Users and their reactions:'),
                    for (var entry in usersWithReactions.entries)
                      Text('${entry.key}: ${entry.value} (${_getReactionText(entry.value)})'),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }




  @override
  void initState() {
    super.initState();
    _loadMessagesFromStorage();
    _loadMessages();
  }

  void _loadMessagesFromStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> messagesJson = prefs.getStringList('messages') ?? [];

    List<Message> messages = messagesJson.map((jsonString) {
      Map<String, dynamic> messageMap = json.decode(jsonString);
      return Message.fromMap('', messageMap);
    }).toList();

    setState(() {
      widget.messages.addAll(messages);
    });
  }



  Future<Map<String, String>> _fetchReactionsAndUsers(Message message) async {
    Map<String, String> usersWithReactions = {};

    try {
      // Assuming you have a 'reactions' node in your database
      DatabaseEvent databaseEvent = await widget._messagesReference
          .child(message.key)
          .child('reactions')
          .once();

      Map<dynamic, dynamic>? reactionsData =
      databaseEvent.snapshot.value as Map<dynamic, dynamic>?;

      if (reactionsData != null) {
        for (var entry in reactionsData.entries) {
          String userId = entry.key;
          String userName = await _getUserName(userId);
          String reaction = entry.value;

          usersWithReactions[userName] = reaction;
        }
      }
    } catch (error) {
      print('Error fetching users and reactions: $error');
    }

    return usersWithReactions;
  }

  Future<String> _getUserName(String userId) async {
    try {
      // Replace this with your logic to get the user name based on userId
      // Assuming you have a 'users' node in your database
      DatabaseEvent databaseEvent = await FirebaseDatabase.instance
          .reference()
          .child('users')
          .child(userId)
          .child('name')
          .once();

      String userName = databaseEvent.snapshot.value.toString();
      return userName;
    } catch (error) {
      print('Error fetching user name: $error');
      return 'Unknown User';
    }
  }
  String _getReactionText(String? reaction) {
    // Map your reactions to text if needed
    switch (reaction) {
      case '😊':
        return 'Smile';
      case '❤️':
        return 'Love';
      case '😢':
        return 'Sad';
      case '😮':
        return 'Surprised';
      case '👍':
        return 'Thumbs Up';
      case '👎':
        return 'Thumbs Down';
      default:
        return 'Unknown Reaction';
    }
  }

  void _navigateToAddFriend(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AddFriendScreen(),
    ),
  );
}
    }

