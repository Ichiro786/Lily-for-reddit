/// Returns the source media ratio when reliable dimensions are available.
///
/// The fallback is intentionally landscape because Reddit posts without preview
/// metadata are commonly links or videos. This helper does not clamp valid
/// ratios, so wide and portrait media retain their intrinsic geometry.
double intrinsicMediaAspectRatio({num? width, num? height}) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 9;
  }
  return width / height;
}

/// Returns the maximum practical feed-media height for the current viewport.
///
/// The policy leaves a small amount of viewport context available around a
/// post, while retaining enough height for normal 9:16 media to render at its
/// natural ratio. Extreme portrait media uses this only as a display cap and
/// remains fully accessible through the existing media viewer.
double mediaViewportMaxHeight({
  required double viewportHeight,
  required double verticalPadding,
}) {
  final available = viewportHeight - verticalPadding - 48;
  return available > 320 ? available : 320;
}

/// Returns a conservative ratio for legacy preview surfaces that require a
/// bounded rectangle. New variable-height feed surfaces should prefer
/// [intrinsicMediaAspectRatio].
double boundedMediaAspectRatio({num? width, num? height}) {
  return intrinsicMediaAspectRatio(width: width, height: height)
      .clamp(0.4, 1.91)
      .toDouble();
}
