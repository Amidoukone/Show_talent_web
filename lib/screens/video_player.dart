import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/admin_theme.dart';
import '../widgets/admin_ui.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    required this.videoUrl,
    required this.userId,
    required this.videoId,
    super.key,
  });

  final String videoUrl;
  final String userId;
  final String videoId;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeVideo;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeVideo = _controller.initialize().then((_) {
      _controller
        ..setLooping(true)
        ..play();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdminAppBackground(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Retour'),
                ),
                const SizedBox(width: 12),
                const AdminPill(
                  label: 'Lecture video',
                  icon: Icons.play_circle_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: AdminGlassPanel(
                padding: const EdgeInsets.all(22),
                highlight: true,
                accentColor: AdminTheme.cyan,
                child: FutureBuilder<void>(
                  future: _initializeVideo,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!_controller.value.isInitialized) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AdminTheme.warning,
                                size: 42,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Impossible de charger la video.\n${widget.videoUrl}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AdminSectionHeader(
                          title: 'Lecteur de moderation',
                          subtitle:
                              'Lecture plein panneau avec controle direct de la video selectionnee.',
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Container(
                              color: Colors.black,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: _controller.value.aspectRatio,
                                  child: VideoPlayer(_controller),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                              ),
                              label: Text(
                                _controller.value.isPlaying
                                    ? 'Pause'
                                    : 'Lecture',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
