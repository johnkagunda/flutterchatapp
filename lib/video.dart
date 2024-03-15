import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Player Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoScreen(),
    );
  }
}

class VideoScreen extends StatefulWidget {
  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<VideoPlayerController> _videoControllers = [];
  List<String> _captions = [];
  List<String> _descriptions = [];
  VideoPlayerController? _selectedVideoController;

  @override
  void initState() {
    super.initState();
    _loadVideosFromDatabase();
  }

  Future<void> _loadVideosFromDatabase() async {
    final databaseReference = _database.reference().child('movies');

    try {
      final databaseEvent = await databaseReference.once();

      final data = databaseEvent.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        data.forEach((key, value) {
          final videoUrl = value['url'] as String;
          final captions = value['captions'] as String;
          final description = value['description'] as String;

          final controller = VideoPlayerController.network(videoUrl);

          setState(() {
            _videoControllers.add(controller);
            _captions.add(captions);
            _descriptions.add(description);
          });
        });
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Movie Videos'),
      ),
      body: Stack(
        children: [
          ListView.builder(
            itemCount: _videoControllers.length,
            itemBuilder: (context, index) {
              final videoController = _videoControllers[index];
              final captions = _captions[index];
              final description = _descriptions[index];

              return VisibilityDetector(
                key: Key(captions), // Using captions as a key, change if needed
                onVisibilityChanged: (visibilityInfo) {
                  if (visibilityInfo.visibleFraction > 0.75) {
                    // Load the video when it's more than 75% visible
                    videoController.initialize();
                  } else {
                    // Pause the video when it's less than 75% visible
                    videoController.pause();
                  }
                },
                child: VideoListItem(
                  controller: videoController,
                  captions: captions,
                  description: description,
                  onTap: () {
                    setState(() {
                      _selectedVideoController = videoController;
                    });
                  },
                ),
              );
            },
          ),
          if (_selectedVideoController != null)
            VideoOverlay(
              controller: _selectedVideoController!,
              onClose: () {
                setState(() {
                  _selectedVideoController!.pause();
                  _selectedVideoController = null;
                });
              },
            ),
        ],
      ),
    );
  }
}

class VideoListItem extends StatelessWidget {
  final VideoPlayerController controller;
  final String captions;
  final String description;
  final VoidCallback onTap;

  VideoListItem({
    required this.controller,
    required this.captions,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '${formatDuration(controller.value.position)} / ${formatDuration(controller.value.duration)}',
            ),
          ),
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Captions: $captions',
                  style: TextStyle(color: Colors.white),
                ),
                Text(
                  'Description: $description',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

class VideoOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onClose;

  VideoOverlay({
    required this.controller,
    required this.onClose,
  });

  @override
  _VideoOverlayState createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<VideoOverlay> {
  late IconData _playPauseIcon;
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _playPauseIcon = Icons.play_arrow;

    // Listen to the video controller for changes in video playback position
    widget.controller.addListener(() {
      setState(() {
        _progressValue = widget.controller.value.position.inMilliseconds /
            widget.controller.value.duration.inMilliseconds;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        widget.controller.seekTo(
                          Duration(
                            milliseconds: (widget.controller.value.position
                                .inMilliseconds -
                                5000), // Rewind 5 seconds
                          ),
                        );
                      },
                      child: Icon(Icons.replay_5),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (widget.controller.value.isPlaying) {
                            widget.controller.pause();
                            _playPauseIcon = Icons.play_arrow;
                          } else {
                            widget.controller.play();
                            _playPauseIcon = Icons.pause;
                          }
                        });
                      },
                      child: Icon(_playPauseIcon),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.controller.seekTo(
                          Duration(
                            milliseconds: (widget.controller.value.position
                                .inMilliseconds +
                                5000), // Fast forward 5 seconds
                          ),
                        );
                      },
                      child: Icon(Icons.forward_5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: ElevatedButton(
              onPressed: widget.onClose,
              child: Icon(Icons.close),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              widget.controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            ),
          ),
        ],
      ),
    );
  }
}
