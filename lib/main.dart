import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/branding.dart';
import 'app/theme.dart';
import 'screens/home_screen.dart';
import 'widgets/crown_mark.dart';
import 'widgets/pixel_art.dart';
import 'widgets/pixel_ui.dart';
import 'widgets/support_developer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  PixelKnightSprite.preloadCommon().ignore();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: RegaliaTheme.midnightBlue,
      systemNavigationBarDividerColor: RegaliaTheme.midnightBlue,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const RegaliaBootstrap());
}

class RegaliaBootstrap extends StatefulWidget {
  const RegaliaBootstrap({super.key});

  @override
  State<RegaliaBootstrap> createState() => _RegaliaBootstrapState();
}

class _RegaliaBootstrapState extends State<RegaliaBootstrap> {
  late final AppController controller;
  Object? error;

  @override
  void initState() {
    super.initState();
    controller = AppController();
    controller.initialize().catchError((Object value) {
      if (mounted) setState(() => error = value);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RegaliaApp(controller: controller, startupError: error);
}

class RegaliaApp extends StatelessWidget {
  const RegaliaApp({
    super.key,
    required this.controller,
    this.startupError,
    this.externalUrlLauncher,
  });
  final AppController controller;
  final Object? startupError;
  final ExternalUrlLauncher? externalUrlLauncher;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder:
        (context, _) => MaterialApp(
          key: ValueKey(controller.gameGeneration),
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: RegaliaTheme.midnight(),
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final portraitWidth =
                media.size.width
                    .clamp(
                      0.0,
                      media.size.height * .62 > 600
                          ? 600
                          : media.size.height * .62,
                    )
                    .toDouble();
            return ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: portraitWidth,
                  height: media.size.height,
                  child: MediaQuery(
                    data: media.copyWith(
                      size: Size(portraitWidth, media.size.height),
                      disableAnimations:
                          media.disableAnimations ||
                          controller.settings.reducedMotion,
                    ),
                    child: child!,
                  ),
                ),
              ),
            );
          },
          home:
              startupError != null
                  ? _StartupError(error: startupError!)
                  : !controller.isReady
                  ? const _LoadingScreen()
                  : HomeScreen(
                    controller: controller,
                    externalUrlLauncher: externalUrlLauncher,
                  ),
        ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox(
        width: 244,
        child: PixelPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CrownMark(size: 64),
              SizedBox(height: 16),
              Text('FORGING THE REALMS', textAlign: TextAlign.center),
              SizedBox(height: 16),
              PixelProgressBar(semanticLabel: 'Opening Queen’s Regalia'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: PixelPanel(
          borderColor: Theme.of(context).colorScheme.error,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelIcon(
                PixelGlyph.error,
                size: 32,
                color: Theme.of(context).colorScheme.error,
                semanticLabel: 'Error',
              ),
              const SizedBox(height: 16),
              const Text(
                '$appName could not open its bundled content manifest.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
