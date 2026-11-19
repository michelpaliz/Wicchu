import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/wicchu_icons.dart';
import '../theme/wicchu_theme.dart';

class FacebookPostLink {
  const FacebookPostLink({required this.url});

  final Uri url;
}

final _facebookUrlPattern = RegExp(
  r'(?:(?:https?://)?(?:www\.)?(?:facebook\.com|fb\.watch)[^\s<>()]+)',
  caseSensitive: false,
);

List<FacebookPostLink> extractFacebookPostLinks(String text) {
  final links = <FacebookPostLink>[];
  final seen = <String>{};
  for (final match in _facebookUrlPattern.allMatches(text)) {
    final raw = match.group(0)!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri == null) continue;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final path = uri.path.toLowerCase();
    final supported = host == 'fb.watch'
        ? uri.pathSegments.isNotEmpty
        : host == 'facebook.com' &&
              (path == '/watch/' ||
                  path == '/watch' ||
                  path.startsWith('/reel/') ||
                  path.contains('/videos/'));
    if (!supported || !seen.add(uri.toString())) continue;
    links.add(FacebookPostLink(url: uri));
  }
  return links;
}

class FacebookPostEmbed extends StatefulWidget {
  const FacebookPostEmbed({
    super.key,
    required this.link,
    this.title,
    this.siteName = 'facebook.com',
  });

  final FacebookPostLink link;
  final String? title;
  final String siteName;

  @override
  State<FacebookPostEmbed> createState() => _FacebookPostEmbedState();
}

class _FacebookPostEmbedState extends State<FacebookPostEmbed> {
  WebViewController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadController();
  }

  void _loadController() {
    if (WebViewPlatform.instance == null) return;
    final embedUrl = Uri.https('www.facebook.com', '/plugins/video.php', {
      'href': widget.link.url.toString(),
      'show_text': 'false',
      'width': '560',
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) {
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(embedUrl);
  }

  @override
  void didUpdateWidget(covariant FacebookPostEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.url != widget.link.url) {
      _failed = false;
      _controller = null;
      _loadController();
    }
  }

  Future<void> _openOriginal() async {
    await launchUrl(widget.link.url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed || _controller == null) {
      return InkWell(
        key: const ValueKey('facebook-preview-fallback'),
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
          AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _controller!),
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
                        WicchuIcons.facebookLogo,
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
