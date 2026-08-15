import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/features/updates/update_checker.dart';

void main() {
  test('normalizes fork release tags and debug versions', () {
    expect(UpdateChecker.normalizeReleaseVersion('v1.0.1'), '1.0.1');
    expect(UpdateChecker.normalizeReleaseVersion('lily-v1.0.1'), '1.0.1');
    expect(UpdateChecker.normalizeReleaseVersion('1.0.0-debug.42'), '1.0.0');
  });

  test('compares three-part semantic release versions', () {
    expect(UpdateChecker.isNewerReleaseVersion('1.0.1', '1.0.0'), isTrue);
    expect(UpdateChecker.isNewerReleaseVersion('1.0.0', '1.0.0'), isFalse);
    expect(UpdateChecker.isNewerReleaseVersion('1.0.0', '1.0.1'), isFalse);
  });
}
