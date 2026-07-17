import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/branding.dart';
import 'app/journey.dart';
import 'app/theme.dart';
import 'screens/journey_screen.dart';
import 'screens/story_scene_screen.dart';
import 'screens/tutorial_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
  const RegaliaApp({super.key, required this.controller, this.startupError});
  final AppController controller;
  final Object? startupError;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder:
        (context, _) => MaterialApp(
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
                  : !controller.tutorialComplete
                  ? TutorialScreen(controller: controller)
                  : !controller.hasSeenStoryBeat(StoryBeatIds.opening)
                  ? StorySceneScreen.opening(controller: controller)
                  : JourneyScreen(controller: controller),
        ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text('$appName could not open its bundled puzzle catalog.'),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
