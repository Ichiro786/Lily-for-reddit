import 'package:flutter/material.dart';

abstract final class ShapeTokens {
  const ShapeTokens._();

  static const BorderRadius full = BorderRadius.all(Radius.circular(999));
  static const BorderRadius extraLarge =
      BorderRadius.all(Radius.circular(28));
  static const BorderRadius large = BorderRadius.all(Radius.circular(24));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(20));
  static const BorderRadius small = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraSmall = BorderRadius.all(Radius.circular(12));
  static const BorderRadius none = BorderRadius.zero;

  static const RoundedRectangleBorder fullShape = RoundedRectangleBorder(
    borderRadius: full,
  );
  static const RoundedRectangleBorder extraLargeShape =
      RoundedRectangleBorder(borderRadius: extraLarge);
  static const RoundedRectangleBorder largeShape = RoundedRectangleBorder(
    borderRadius: large,
  );
  static const RoundedRectangleBorder mediumShape = RoundedRectangleBorder(
    borderRadius: medium,
  );
  static const RoundedRectangleBorder smallShape = RoundedRectangleBorder(
    borderRadius: small,
  );
  static const RoundedRectangleBorder extraSmallShape =
      RoundedRectangleBorder(borderRadius: extraSmall);
  static const RoundedRectangleBorder noneShape = RoundedRectangleBorder(
    borderRadius: none,
  );
}
