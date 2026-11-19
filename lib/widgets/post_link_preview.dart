import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/community_models.dart';
import '../theme/wicchu_icons.dart';
import '../theme/wicchu_theme.dart';
import 'wicchu_network_image.dart';
import 'youtube_post_embed.dart';

final _postUrlPattern = RegExp(
  r'(?:(?:https?://)|(?:(?:www\.)?(?:youtube\.com|youtu\.be|facebook\.com|fb\.watch)/))[^\s<>()]+',
  caseSensitive: false,
);
final _markdownAutoLinkPattern = RegExp(
  r'\[((?:https?://)[^\]\s]+)\]\(((?:https?://)[^)\s]+)\)',
  caseSensitive: false,
);
final _youtubeTextPattern = RegExp(
  r'(?:(?:https?://)?(?:www\.)?(?:youtube\.com|youtu\.be)[^\s<>()\]]+)',
  caseSensitive: false,
);
final _markdownEscapedPunctuation = RegExp(r'''\\([\\`*_{}\[\]()#+\-.!])''');

String _unescapeMarkdownLabel(String value) => value.replaceAllMapped(
  _markdownEscapedPunctuation,
  (match) => match.group(1)!,
);

class DetectedPostUrl {
  const DetectedPostUrl({
    required this.uri,
    required this.start,
    required this.end,
  });

  final Uri uri;
  final int start;
  final int end;
}

List<DetectedPostUrl> detectPostUrls(String text) {
  final links = <DetectedPostUrl>[];
  for (final match in _postUrlPattern.allMatches(text)) {
    var raw = match.group(0)!;
    raw = raw.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    final uri = Uri.tryParse(
      raw.startsWith(RegExp(r'https?://')) ? raw : 'https://$raw',
    );
    if (uri == null || uri.host.isEmpty) continue;
    links.add(
      DetectedPostUrl(
        uri: uri,
        start: match.start,
        end: match.start + raw.length,
      ),
    );
  }
  return links;
}

String _comparableUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final path = uri.path == '/' ? '' : uri.path.replaceFirst(RegExp(r'/$'), '');
  return uri
      .replace(scheme: 'https', host: host, path: path, fragment: '')
      .toString();
}

bool postUrlsMatch(Uri first, Uri second) =>
    _comparableUrl(first) == _comparableUrl(second);

/// Removes only the raw URL represented by an inline preview. The stored post
/// text remains unchanged, and all other URLs remain visible.
String displayTextWithoutPreviewUrl(String text, Uri? representedUrl) {
  if (representedUrl == null) return text;
  for (final match in _markdownAutoLinkPattern.allMatches(text)) {
    final label = _unescapeMarkdownLabel(match.group(1)!);
    final destination = match.group(2)!;
    final labelUri = Uri.tryParse(label);
    final destinationUri = Uri.tryParse(destination);
    if (labelUri != null &&
        destinationUri != null &&
        postUrlsMatch(labelUri, destinationUri) &&
        postUrlsMatch(destinationUri, representedUrl)) {
      return _cleanTextAfterPreviewRemoval(
        text.replaceRange(match.start, match.end, ''),
      );
    }
  }
  final link = detectPostUrls(text).where((candidate) {
    final markdownPrefix = candidate.start >= 2
        ? text.substring(candidate.start - 2, candidate.start)
        : '';
    return markdownPrefix != '](' &&
        postUrlsMatch(candidate.uri, representedUrl);
  }).firstOrNull;
  if (link == null) {
    final representedYoutube = extractYoutubePostLinks(
      representedUrl.toString(),
    ).firstOrNull;
    if (representedYoutube == null) return text;
    for (final match in _youtubeTextPattern.allMatches(text)) {
      if (match.start >= 2 &&
          text.substring(match.start - 2, match.start) == '](') {
        continue;
      }
      final normalized = _unescapeMarkdownLabel(match.group(0)!);
      final candidate = extractYoutubePostLinks(normalized).firstOrNull;
      if (candidate?.videoId == representedYoutube.videoId) {
        return _cleanTextAfterPreviewRemoval(
          text.replaceRange(match.start, match.end, ''),
        );
      }
    }
    return text;
  }

  return _cleanTextAfterPreviewRemoval(
    text.replaceRange(link.start, link.end, ''),
  );
}

String _cleanTextAfterPreviewRemoval(String text) => text
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n[ \t]+'), '\n')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAllMapped(RegExp(r' +([,.;:!?])'), (match) => match.group(1)!)
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

class PostLinkPreviewCard extends StatefulWidget {
  const PostLinkPreviewCard({super.key, required this.preview});

  final PostLinkPreview preview;

  @override
  State<PostLinkPreviewCard> createState() => _PostLinkPreviewCardState();
}

class _PostLinkPreviewCardState extends State<PostLinkPreviewCard> {
  bool _imageFailed = false;

  Uri get _uri => Uri.parse(widget.preview.url);

  Future<void> _open() async {
    await launchUrl(_uri, mode: LaunchMode.externalApplication);
  }

  @override
  void didUpdateWidget(covariant PostLinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview.imageUrl != widget.preview.imageUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_imageFailed) {
      return Semantics(
        link: true,
        child: InkWell(
          key: const ValueKey('post-link-preview-fallback'),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              widget.preview.url,
              style: WicchuPostTypography.body(
                context,
              ).copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ),
      );
    }

    final domain = widget.preview.siteName.trim().isEmpty
        ? _uri.host.replaceFirst(RegExp(r'^www\.'), '')
        : widget.preview.siteName.trim();
    return Semantics(
      button: true,
      link: true,
      label: '${widget.preview.title}, $domain',
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('post-link-preview'),
          onTap: _open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: WicchuNetworkImage(
                  url: widget.preview.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorBuilder: (context) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _imageFailed = true);
                    });
                    return ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          WicchuIcons.globe,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WicchuPostTypography.metadata(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.preview.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WicchuPostTypography.title(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
