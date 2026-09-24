import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';

Future<void> openPostMediaViewer(
  BuildContext context,
  List<PostMedia> media, {
  int initialIndex = 0,
}) async {
  if (media.isEmpty) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PostMediaViewer(media: media, initialIndex: initialIndex),
    ),
  );
}

/// Equal-width previews; the viewer always receives the complete media list.
class PostMediaGallery extends StatelessWidget {
  const PostMediaGallery({super.key, required this.media});
  final List<PostMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final count = media.length > 2 ? 2 : media.length;
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                label: context.tr('Open media {number} of {total}', {
                  'number': '${index + 1}',
                  'total': '${media.length}',
                }),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (media[index].type == 'video')
                        _MediaVideo(
                          key: ValueKey(media[index].url),
                          url: media[index].url,
                          preview: true,
                        )
                      else
                        _MediaImage(url: media[index].url, fit: BoxFit.cover),
                      if (media[index].type == 'video')
                        const Center(
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.play_arrow_rounded),
                          ),
                        ),
                      if (index == 1 && media.length > 2)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '+${media.length - 2}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('open-post-media-$index'),
                          onTap: () => openPostMediaViewer(
                            context,
                            media,
                            initialIndex: index,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PostMediaViewer extends StatefulWidget {
  const PostMediaViewer({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });
  final List<PostMedia> media;
  final int initialIndex;

  @override
  State<PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends State<PostMediaViewer> {
  late int _index = widget.initialIndex.clamp(0, widget.media.length - 1);
  late final _pages = PageController(initialPage: _index);
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('${_index + 1} / ${widget.media.length}'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: widget.media.length,
              onPageChanged: (index) => setState(() {
                _index = index;
                _zoomed = false;
              }),
              itemBuilder: (context, index) {
                final item = widget.media[index];
                return item.type == 'video'
                    ? _MediaVideo(
                        key: ValueKey('video-$index-${item.url}'),
                        url: item.url,
                        active: index == _index,
                      )
                    : _ZoomableImage(
                        key: ValueKey('image-$index-${item.url}'),
                        url: item.url,
                        active: index == _index,
                        onZoomChanged: (zoomed) {
                          if (index == _index && zoomed != _zoomed) {
                            setState(() => _zoomed = zoomed);
                          }
                        },
                      );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.tr('Previous media'),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    context.tr(
                      widget.media[_index].type == 'video'
                          ? 'Swipe to browse media'
                          : 'Pinch or double-tap to zoom',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Next media'),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  onPressed: _index < widget.media.length - 1
                      ? () => _goTo(_index + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    super.key,
    required this.url,
    required this.active,
    required this.onZoomChanged,
  });
  final String url;
  final bool active;
  final ValueChanged<bool> onZoomChanged;
  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  @override
  void didUpdateWidget(covariant _ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
    onDoubleTap: () {
      final zoomIn = _transform.value.getMaxScaleOnAxis() <= 1.01;
      _transform.value = zoomIn
          ? Matrix4.fromList([
              2.5,
              0,
              0,
              0,
              0,
              2.5,
              0,
              0,
              0,
              0,
              2.5,
              0,
              -_doubleTapPosition.dx * 1.5,
              -_doubleTapPosition.dy * 1.5,
              0,
              1,
            ])
          : Matrix4.identity();
      widget.onZoomChanged(zoomIn);
    },
    child: InteractiveViewer(
      transformationController: _transform,
      panEnabled: _transform.value.getMaxScaleOnAxis() > 1.01,
      minScale: 1,
      maxScale: 5,
      onInteractionUpdate: (_) =>
          widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
      child: SizedBox.expand(
        child: _MediaImage(url: widget.url, fit: BoxFit.contain),
      ),
    ),
  );
}

class _MediaImage extends StatefulWidget {
  const _MediaImage({required this.url, required this.fit});
  final String url;
  final BoxFit fit;
  @override
  State<_MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<_MediaImage> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => Image.network(
    widget.url,
    key: ValueKey('${widget.url}-$_attempt'),
    fit: widget.fit,
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (_, _, _) => _MediaError(
      onRetry: () async {
        await NetworkImage(widget.url).evict();
        if (mounted) setState(() => _attempt++);
      },
    ),
  );
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF252525),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.white70),
          const SizedBox(height: 8),
          Text(
            context.tr('Could not load media'),
            style: const TextStyle(color: Colors.white),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(context.tr('Retry')),
          ),
        ],
      ),
    ),
  );
}

class _MediaVideo extends StatefulWidget {
  const _MediaVideo({
    super.key,
    required this.url,
    this.preview = false,
    this.active = false,
  });
  final String url;
  final bool preview;
  final bool active;

  @override
  State<_MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<_MediaVideo> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  late Future<void> _ready;

  void _initialize() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ready = _controller.initialize();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _MediaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _controller.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    await _controller.dispose();
    if (mounted) setState(_initialize);
  }

  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _MediaError(onRetry: _retry);
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          if (value.hasError) return _MediaError(onRetry: _retry);
          if (widget.preview) {
            return Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Text(
                        _time(value.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: context.tr(
                        value.isPlaying ? 'Pause video' : 'Play video',
                      ),
                      color: Colors.white,
                      onPressed: widget.active
                          ? () async {
                              if (value.isPlaying) {
                                await _controller.pause();
                              } else {
                                if (value.position >= value.duration) {
                                  await _controller.seekTo(Duration.zero);
                                }
                                await _controller.play();
                              }
                            }
                          : null,
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_time(value.position)} / ${_time(value.duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
