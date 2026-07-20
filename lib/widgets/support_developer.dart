import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pixel_ui.dart';

final Uri buyMeACoffeeUri = Uri.https('buymeacoffee.com', '/philosophyforge');

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> launchExternalSupportUrl(Uri uri) => launchUrl(
  uri,
  mode: LaunchMode.externalApplication,
  webOnlyWindowName: '_blank',
);

Future<void> openSupportPage(
  BuildContext context, {
  ExternalUrlLauncher? externalUrlLauncher,
}) async {
  var opened = false;
  try {
    opened = await (externalUrlLauncher ?? launchExternalSupportUrl)(
      buyMeACoffeeUri,
    );
  } on Object {
    opened = false;
  }
  if (!context.mounted || opened) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Could not open the support page.')),
    );
}

class SupportDeveloperPanel extends StatelessWidget {
  const SupportDeveloperPanel({super.key, this.externalUrlLauncher});

  final ExternalUrlLauncher? externalUrlLauncher;

  @override
  Widget build(BuildContext context) => PixelPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelIcon(
              PixelGlyph.cup,
              color: Theme.of(context).colorScheme.secondary,
              size: 32,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support the developer',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Enjoying Queen’s Regalia? You can help fund more puzzles, art, and story chapters.',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          key: const ValueKey('open-buy-me-a-coffee'),
          onPressed:
              () => openSupportPage(
                context,
                externalUrlLauncher: externalUrlLauncher,
              ),
          icon: const PixelIcon(
            PixelGlyph.cup,
            size: 24,
            excludeFromSemantics: true,
          ),
          label: const Text('Buy me a coffee'),
        ),
      ],
    ),
  );
}
