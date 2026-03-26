import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/core/binary_manager.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_bloc.dart';
import 'package:frameextractor/presentation/screens/home_screen.dart';
import 'package:frameextractor/presentation/screens/splash_screen.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

const bool kIsPortable = bool.fromEnvironment('PORTABLE', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppPrefs.init();

  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1020, 640),
        minimumSize: Size(640, 420),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        title: AppConstants.appName,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return AppThemeProvider(
      initialThemeMode: AppPrefs.themeMode,
      initialUIStyle: AppPrefs.uiStyle,
      child: Builder(
        builder: (ctx) {
          final theme = AppTheme.of(ctx);
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: theme.toMaterialTheme(),
            home: const _InitGate(),
          );
        },
      ),
    );
  }
}

class _InitGate extends StatefulWidget {
  const _InitGate();

  @override
  State<_InitGate> createState() => _InitGateState();
}

class _InitGateState extends State<_InitGate> {
  String _status = 'Preparing…';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (!Platform.isIOS) {
        setState(() => _status = 'Extracting binaries…');
        await BinaryManager.instance.initialize(isPortable: kIsPortable);

        setState(() => _status = 'Verifying…');
        final test = await BinaryManager.instance.selfTest();

        if (!test.ffmpeg || !test.ytDlp) {
          setState(() {
            _error = true;
            _status =
                'Binary check failed.\n'
                'ffmpeg: ${test.ffmpeg ? "✓" : "✗"}  '
                'yt-dlp: ${test.ytDlp ? "✓" : "✗"}';
          });
          return;
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => BlocProvider(
            create: (_) => ExtractionBloc(
              ffmpegService: createFFmpegService(),
              youTubeService: YouTubeService(),
            ),
            child: const HomeScreen(),
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      setState(() {
        _error = true;
        _status = 'Init error:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SplashScreen(
    status: _status,
    hasError: _error,
    onRetry: _error
        ? () {
            setState(() {
              _error = false;
              _status = 'Retrying…';
            });
            _init();
          }
        : null,
  );
}
