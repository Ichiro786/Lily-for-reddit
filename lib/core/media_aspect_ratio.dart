double boundedMediaAspectRatio({num? width, num? height}) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 9;
  }
  return (width / height).clamp(0.35, 2.0).toDouble();
}
