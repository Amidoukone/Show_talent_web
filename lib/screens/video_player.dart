import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String userId; // Ajoutez cet attribut si vous devez l'utiliser pour l'utilisateur
  final String videoId; // Ajoutez cet attribut pour l'ID de la vidéo

  const VideoPlayerScreen({super.key, required this.videoUrl, required this.userId, required this.videoId});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
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
      appBar: AppBar(
        title: const Text('Lecteur de Vidéo'),
        backgroundColor: const Color.fromARGB(255, 27, 56, 56), // Couleur de fond de l'app bar
        iconTheme: const IconThemeData(color: Colors.white), // Icônes en blanc
      ),
      body: Container(
        color: const Color.fromARGB(255, 0, 0, 0), // Couleur de fond vert foncé
        child: Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const CircularProgressIndicator(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
        backgroundColor: Colors.green[800],
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white, // Icône du bouton play en blanc
        ), // Couleur de fond du bouton
      ),
    );
  }
}