import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

String stableImageCacheKey(String url, {String? cacheKey}) {
  if (cacheKey?.trim().isNotEmpty == true) return cacheKey!.trim();
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  // Query parameters may identify the image (for example blobName) or its
  // version. Removing them can serve an older or entirely different upload.
  const signingParameters = {'sig', 'se', 'st', 'sp', 'sv', 'sr', 'spr', 'sip'};
  final parameters = Map<String, dynamic>.from(uri.queryParametersAll)
    ..removeWhere((key, _) => signingParameters.contains(key.toLowerCase()));
  return uri.replace(queryParameters: parameters, fragment: '').toString();
}

class WicchuNetworkImage extends StatelessWidget {
  const WicchuNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    this.cacheKey,
    this.width,
    this.height,
    this.decodeWidth,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;
  final String? cacheKey;
  final double? width;
  final double? height;
  final int? decodeWidth;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: url,
    cacheKey: stableImageCacheKey(url, cacheKey: cacheKey),
    width: width,
    height: height,
    fit: fit,
    memCacheWidth: decodeWidth,
    maxWidthDiskCache: decodeWidth,
    fadeInDuration: const Duration(milliseconds: 120),
    placeholder: loadingBuilder == null
        ? null
        : (context, _) => loadingBuilder!(context),
    errorWidget: errorBuilder == null
        ? null
        : (context, _, _) => errorBuilder!(context),
  );
}
