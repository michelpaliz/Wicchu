import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewPlatform;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../theme/wicchu_icons.dart';
import '../theme/wicchu_theme.dart';
import 'wicchu_network_image.dart';

/// A validated YouTube link found in post text.
class YoutubePostLink {
  const YoutubePostLink({required this.videoId, required this.url});

  final String videoId;
  final Uri url;
}

final _youtubeUrlPattern = RegExp(
  r'(?:(?:https?://)?(?:www\.)?(?:youtube\.com|youtu\.be)[^\s<>()]+)',
  caseSensitive: false,
);
final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Finds supported YouTube watch, short, live, and shortened links.
/// Invalid or unsupported links are ignored and remain rendered by the post.
List<YoutubePostLink> extractYoutubePostLinks(String text) {
  final links = <YoutubePostLink>[];
  final seen = <String>{};
  for (final match in _youtubeUrlPattern.allMatches(text)) {
    final raw = match.group(0)!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri == null) continue;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host != 'youtube.com' && host != 'youtu.be') continue;

    String? id;
    if (host == 'youtu.be') {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (uri.path == '/watch' || uri.path == '/watch/') {
      id = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        (uri.pathSegments.first == 'shorts' ||
            uri.pathSegments.first == 'live' ||
            uri.pathSegments.first == 'embed')) {
      id = uri.pathSegments[1];
    }
    if (id == null || !_videoIdPattern.hasMatch(id) || !seen.add(id)) continue;
    links.add(YoutubePostLink(videoId: id, url: uri));
  }
  return links;
}

class YoutubePostEmbed extends StatefulWidget {
  const YoutubePostEmbed({
    super.key,
    required this.link,
    this.title,
    this.siteName = 'youtube.com',
  });

  final YoutubePostLink link;
  final String? title;
  final String siteName;

  @override
  State<YoutubePostEmbed> createState() => _YoutubePostEmbedState();
}

class _YoutubePostEmbedState extends State<YoutubePostEmbed> {
  YoutubePlayerController? _controller;
  bool _thumbnailFailed = false;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance == null) return;
    _controller = _createController();
  }

  YoutubePlayerController _createController() {
    final controller = YoutubePlayerController(
      key: widget.link.videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    controller.cueVideoById(videoId: widget.link.videoId);
    return controller;
  }

  @override
  void didUpdateWidget(covariant YoutubePostEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.videoId != widget.link.videoId) {
      _thumbnailFailed = false;
      _controller?.close();
      if (WebViewPlatform.instance == null) {
        _controller = null;
        return;
      }
      _controller = _createController();
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _openOriginal() async {
    await launchUrl(widget.link.url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_thumbnailFailed) {
      return InkWell(
        key: const ValueKey('youtube-preview-fallback'),
        onTap: _openOriginal,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            widget.link.url.toString(),
            style: WicchuPostTypography.body(
              context,
            ).copyWith(color: theme.colorScheme.primary),
          ),
        ),
      );
    }
    final title = widget.title?.trim() ?? '';
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_controller != null)
            YoutubePlayerThumbnail(
              controller: _controller!,
              aspectRatio: 16 / 9,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            )
          else
            InkWell(
              onTap: _openOriginal,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    WicchuNetworkImage(
                      url:
                          'https://i.ytimg.com/vi/${widget.link.videoId}/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _thumbnailFailed = true);
                          }
                        });
                        return ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                        );
                      },
                    ),
                    Center(
                      child: IgnorePointer(
                        child: IconButton.filled(
                          onPressed: () {},
                          icon: const Icon(WicchuIcons.playFill),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          InkWell(
            onTap: _openOriginal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        WicchuIcons.playCircle,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.siteName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WicchuPostTypography.metadata(context),
                        ),
                      ),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WicchuPostTypography.title(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
