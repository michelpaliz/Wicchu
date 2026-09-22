import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = Uri.tryParse(imageUrl?.trim() ?? '');
    final canLoadImage = uri != null && {'http', 'https'}.contains(uri.scheme);
    final fallback = _AvatarFallback(
      name: name,
      foregroundColor: foregroundColor ?? theme.colorScheme.primary,
    );

    return Semantics(
      image: canLoadImage,
      label: name,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? theme.colorScheme.primaryContainer,
        ),
        child: canLoadImage
            ? Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name, required this.foregroundColor});

  final String name;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return Center(
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}
