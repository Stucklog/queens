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
  });

  factory ContentEntitlementPolicy.current({
    Set<String> grantedEntitlementIds = const {},
  }) => ContentEntitlementPolicy(
    channel: kIsWeb ? ReleaseChannel.web : ReleaseChannel.paidPlatform,
    grantedEntitlementIds: grantedEntitlementIds,
  );

  const ContentEntitlementPolicy.web()
    : channel = ReleaseChannel.web,
      grantedEntitlementIds = const {};

  const ContentEntitlementPolicy.paidPlatform({
    this.grantedEntitlementIds = const {},
  }) : channel = ReleaseChannel.paidPlatform;

  final ReleaseChannel channel;
  final Set<String> grantedEntitlementIds;

  bool includesArc(String arcId, Set<ReleaseChannel> packageChannels) =>
      packageChannels.contains(channel) &&
      (channel != ReleaseChannel.web || arcId == ContentIds.originArc);

  bool isEntitled(String entitlementId) =>
      entitlementId == ContentIds.originEntitlement ||
      entitlementId == ContentIds.justPuzzleEntitlement ||
      grantedEntitlementIds.contains(entitlementId);
}
