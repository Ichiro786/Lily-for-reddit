import 'package:flutter/material.dart';

/// Messenger scope that remains mounted while modal routes are presented.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showRootSnackBar(SnackBar snackBar) {
  rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}

