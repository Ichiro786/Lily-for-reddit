/// Returns whether the provided dimensions represent valid, non-zero media dimensions.
bool hasMediaDimensions({num? width, num? height}) {
  return width != null && height != null && width > 0 && height > 0;
}

/// Returns the source media ratio when reliable dimensions are available.
///
/// If width or height are missing or non-positive, returns [fallback] (defaults to
/// 4 / 3, the standard photographic ratio). Callers may supply a specialized fallback
/// (e.g. 16 / 9 for video posts).
double intrinsicMediaAspectRatio({
  num? width,
  num? height,
  double fallback = 4 / 3,
}) {
  if (!hasMediaDimensions(width: width, height: height)) {
    return fallback;
  }
  return (width! / height!).toDouble();
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
  return intrinsicMediaAspectRatio(
    width: width,
    height: height,
    fallback: 16 / 9,
  ).clamp(0.4, 1.91).toDouble();
}
