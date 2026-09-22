import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/community_models.dart';

class PostMediaGallery extends StatelessWidget {
  const PostMediaGallery({super.key, required this.media});

  final List<PostMedia> media;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 190,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: media.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final item = media[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: item.type == 'video'
              ? _NetworkVideo(url: item.url)
              : Image.network(
                  item.url,
                  width: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 260,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
        );
      },
    ),
  );
}

class _NetworkVideo extends StatefulWidget {
  const _NetworkVideo({required this.url});

  final String url;

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ready = _controller.initialize().then((_) => _controller.setLooping(true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.videocam_off_outlined),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              }),
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ],
        );
      },
    ),
  );
}
