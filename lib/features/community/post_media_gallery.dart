import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../../widgets/wicchu_network_image.dart';

Future<void> openPostMediaViewer(
  BuildContext context,
  List<PostMedia> media, {
  int initialIndex = 0,
  WidgetBuilder? contentBuilder,
  WidgetBuilder? actionsBuilder,
  String? author,
}) async {
  if (media.isEmpty) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PostMediaViewer(
        media: media,
        initialIndex: initialIndex,
        contentBuilder: contentBuilder,
        actionsBuilder: actionsBuilder,
        author: author,
      ),
    ),
  );
}

/// Equal-width previews; the viewer always receives the complete media list.
class PostMediaGallery extends StatelessWidget {
  const PostMediaGallery({super.key, required this.media, this.onOpen});
  final List<PostMedia> media;
  final ValueChanged<int>? onOpen;

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
                        _MediaImage(
                          url: media[index].previewUrl,
                          cacheKey: media[index].previewCacheKey,
                          fit: BoxFit.cover,
                          decodeWidth: 1200,
                        ),
                      if (media[index].type == 'video')
                        const Center(
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            child: Icon(WicchuIcons.playFill),
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
                          onTap: () => onOpen != null
                              ? onOpen!(index)
                              : openPostMediaViewer(
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
    this.contentBuilder,
    this.actionsBuilder,
    this.author,
  });
  final List<PostMedia> media;
  final int initialIndex;
  final WidgetBuilder? contentBuilder;
  final WidgetBuilder? actionsBuilder;
  final String? author;

  @override
  State<PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends State<PostMediaViewer> {
  late int _index = widget.initialIndex.clamp(0, widget.media.length - 1);
  late final _pages = PageController(initialPage: _index);
  bool _zoomed = false;
  final _imageRatios = <String, double>{};
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageSize();
  }

  void _resolveImageSize() {
    final previousListener = _imageListener;
    if (previousListener != null) {
      _imageStream?.removeListener(previousListener);
    }
    _imageStream = null;
    _imageListener = null;
    final item = widget.media[_index];
    if (item.type == 'video' || _imageRatios.containsKey(item.url)) return;
    final stream = CachedNetworkImageProvider(
      item.url,
      cacheKey: stableImageCacheKey(item.url, cacheKey: item.blobName),
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, synchronousCall) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        if (!mounted) return;
        if (synchronousCall) {
          _imageRatios[item.url] = ratio;
        } else {
          setState(() => _imageRatios[item.url] = ratio);
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        // The image widget supplies the existing error and retry controls.
      },
    );
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    final listener = _imageListener;
    if (listener != null) _imageStream?.removeListener(listener);
    _pages.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  final _scroll = ScrollController();
  bool _immersive = false;
  double _savedOffset = 0;
  double _mediaHeight = 0;
  bool _mediaVisible = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final visible = _scroll.offset < _mediaHeight;
      if (visible != _mediaVisible) setState(() => _mediaVisible = visible);
    });
  }

  void _toggleChrome() {
    if (!_immersive) {
      _savedOffset = _scroll.offset;
      _scroll.jumpTo(0);
    }
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (!_immersive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(
            _savedOffset.clamp(0, _scroll.position.maxScrollExtent),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF80CBC4),
        brightness: Brightness.dark,
        surface: const Color(0xFF151A1A),
      ),
      scaffoldBackgroundColor: Colors.black,
      cardTheme: const CardThemeData(
        color: Color(0xFF151A1A),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: dark,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              top: !_immersive,
              bottom: !_immersive,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final ratio = _imageRatios[widget.media[_index].url];
                  _mediaHeight = _immersive || widget.contentBuilder == null
                      ? height
                      : ratio == null
                      ? height * .74
                      : (constraints.maxWidth / ratio).clamp(
                          56.0,
                          height * .74,
                        );
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scroll,
                        physics: _immersive || _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          children: [
                            SizedBox(
                              height: _mediaHeight,
                              child: PageView.builder(
                                controller: _pages,
                                physics: _zoomed
                                    ? const NeverScrollableScrollPhysics()
                                    : null,
                                itemCount: widget.media.length,
                                onPageChanged: (index) => setState(() {
                                  _index = index;
                                  _zoomed = false;
                                  _resolveImageSize();
                                }),
                                itemBuilder: (context, index) {
                                  final item = widget.media[index];
                                  return item.type == 'video'
                                      ? _MediaVideo(
                                          key: ValueKey(
                                            'video-$index-${item.url}',
                                          ),
                                          url: item.url,
                                          active:
                                              index == _index && _mediaVisible,
                                          immersive: _immersive,
                                          onTap: _toggleChrome,
                                        )
                                      : _ZoomableImage(
                                          key: ValueKey(
                                            'image-$index-${item.url}',
                                          ),
                                          url: item.url,
                                          cacheKey: item.blobName,
                                          active: index == _index,
                                          onTap: _toggleChrome,
                                          onZoomChanged: (zoomed) {
                                            if (mounted &&
                                                index == _index &&
                                                zoomed != _zoomed) {
                                              setState(() => _zoomed = zoomed);
                                            }
                                          },
                                        );
                                },
                              ),
                            ),
                            if (widget.contentBuilder != null)
                              Offstage(
                                offstage: _immersive,
                                child: widget.contentBuilder!(context),
                              ),
                          ],
                        ),
                      ),
                      if (!_immersive)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ColoredBox(
                            color: Colors.black54,
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).closeButtonTooltip,
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(WicchuIcons.arrowLeft),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.author ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${_index + 1} / ${widget.media.length}'),
                                if (widget.actionsBuilder != null)
                                  widget.actionsBuilder!(context)
                                else
                                  const SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),
                      if (!_immersive && widget.contentBuilder == null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: context.tr('Previous media'),
                                onPressed: _index > 0
                                    ? () => _goTo(_index - 1)
                                    : null,
                                icon: const Icon(WicchuIcons.caretLeft),
                              ),
                              Expanded(
                                child: Text(
                                  context.tr('Pinch or double-tap to zoom'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                tooltip: context.tr('Next media'),
                                onPressed: _index < widget.media.length - 1
                                    ? () => _goTo(_index + 1)
                                    : null,
                                icon: const Icon(WicchuIcons.caretRight),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    super.key,
    required this.url,
    this.cacheKey,
    required this.active,
    required this.onZoomChanged,
    required this.onTap,
  });
  final String url;
  final String? cacheKey;
  final bool active;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;
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
    onTap: widget.onTap,
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
        child: _MediaImage(
          url: widget.url,
          cacheKey: widget.cacheKey,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

class _MediaImage extends StatefulWidget {
  const _MediaImage({
    required this.url,
    required this.fit,
    this.cacheKey,
    this.decodeWidth,
  });
  final String url;
  final BoxFit fit;
  final String? cacheKey;
  final int? decodeWidth;
  @override
  State<_MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<_MediaImage> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => WicchuNetworkImage(
    key: ValueKey('${widget.url}-$_attempt'),
    url: widget.url,
    cacheKey: widget.cacheKey,
    fit: widget.fit,
    decodeWidth: widget.decodeWidth,
    loadingBuilder: (_) => const ColoredBox(
      color: Color(0x11000000),
      child: Center(child: Icon(WicchuIcons.image, color: Colors.white54)),
    ),
    errorBuilder: (_) => _MediaError(
      onRetry: () async {
        await CachedNetworkImage.evictFromCache(
          widget.url,
          cacheKey: stableImageCacheKey(widget.url, cacheKey: widget.cacheKey),
        );
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
          const Icon(WicchuIcons.imageBroken, color: Colors.white70),
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
    this.immersive = false,
    this.onTap,
  });
  final String url;
  final bool preview;
  final bool immersive;
  final VoidCallback? onTap;
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
                    child: GestureDetector(
                      onTap: widget.onTap,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              ),
              if (!widget.immersive)
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
                          value.isPlaying
                              ? WicchuIcons.pause
                              : WicchuIcons.playFill,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
