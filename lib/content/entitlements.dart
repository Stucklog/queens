import 'package:flutter/foundation.dart';

import 'content_ids.dart';

enum ReleaseChannel { web, paidPlatform }

/// Selects the browser catalog or the complete installed-app catalog.
///
/// Native storefronts sell the app once; there are no per-arc purchases or
/// receipt gates. [grantedEntitlementIds] remains only for explicit package-
/// isolation policies and is never supplied by the shipping app.
class ContentEntitlementPolicy {
  const ContentEntitlementPolicy({
    required this.channel,
    this.grantedEntitlementIds = const {},
    this.grantChannelEntitlements = false,
  });

  factory ContentEntitlementPolicy.current({
    Set<String> grantedEntitlementIds = const {},
  }) => ContentEntitlementPolicy(
    channel: kIsWeb ? ReleaseChannel.web : ReleaseChannel.paidPlatform,
    grantedEntitlementIds: grantedEntitlementIds,
    grantChannelEntitlements: true,
  );

  const ContentEntitlementPolicy.web()
    : channel = ReleaseChannel.web,
      grantedEntitlementIds = const {},
      grantChannelEntitlements = true;

  const ContentEntitlementPolicy.paidPlatform({
    this.grantedEntitlementIds = const {},
  }) : channel = ReleaseChannel.paidPlatform,
       grantChannelEntitlements = true;

  final ReleaseChannel channel;
  final Set<String> grantedEntitlementIds;
  final bool grantChannelEntitlements;

  bool includesArc(Set<ReleaseChannel> packageChannels) =>
      packageChannels.contains(channel);

  bool isEntitled(String entitlementId) =>
      grantChannelEntitlements ||
      entitlementId == ContentIds.originEntitlement ||
      entitlementId == ContentIds.justPuzzleEntitlement ||
      grantedEntitlementIds.contains(entitlementId);
}
