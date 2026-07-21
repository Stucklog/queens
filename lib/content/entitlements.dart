import 'package:flutter/foundation.dart';

import 'content_ids.dart';

enum ReleaseChannel { web, paidPlatform }

/// Separates content packaging from the right to use that content.
///
/// Store purchase/receipt code can translate its result into
/// [grantedEntitlementIds] without coupling content loading to a storefront.
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
