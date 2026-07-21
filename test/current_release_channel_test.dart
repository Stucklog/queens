import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/content/entitlements.dart';

void main() {
  test('web builds select the web content channel', () {
    final policy = ContentEntitlementPolicy.current();

    expect(
      policy.channel,
      kIsWeb ? ReleaseChannel.web : ReleaseChannel.paidPlatform,
    );
    expect(policy.grantChannelEntitlements, isTrue);
  });
}
