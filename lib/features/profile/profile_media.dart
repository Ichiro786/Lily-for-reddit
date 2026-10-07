import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

bool validProfileImage(String? url) {
  final uri = Uri.tryParse(url ?? '');
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.username,
    this.url,
    this.size = 56,
  });
  final String username;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget fallback() => ColoredBox(
      color: cs.primaryContainer,
      child: Center(
        child: Text(
          username.isEmpty ? '?' : username.characters.first.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: cs.onPrimaryContainer),
        ),
      ),
    );
    return Semantics(
      image: true,
      label: 'Profile picture of $username',
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: validProfileImage(url)
              ? CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => fallback(),
                  errorWidget: (_, __, ___) => fallback(),
                )
              : fallback(),
        ),
      ),
    );
  }
}

class ProfileBanner extends StatelessWidget {
  const ProfileBanner({super.key, this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget fallback() => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.surfaceContainerLow],
        ),
      ),
      child: Icon(
        Icons.landscape_outlined,
        size: 48,
        color: cs.onPrimaryContainer.withValues(alpha: .6),
      ),
    );
    return AspectRatio(
      aspectRatio: 2.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: validProfileImage(url)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback(),
                errorWidget: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}
