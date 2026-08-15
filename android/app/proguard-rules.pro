# App-specific R8 rules.
#
# The current Android integration points are retained through direct references
# or manifest declarations: Flutter's generated plugin registrant, the manifest
# application/activity entries, flutter_web_auth_2's CallbackActivity, and the
# Flutter/Dart entry points marked with @pragma('vm:entry-point').
#
# Keep this file intentionally empty of broad package rules. Add a narrowly
# scoped rule only when a release smoke test or R8 warning demonstrates a
# reflection/resource lookup that needs it.
