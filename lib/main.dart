import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'package:frameextractor/core/binary_manager.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_bloc.dart';
import 'package:frameextractor/presentation/screens/home_screen.dart';
import 'package:frameextractor/presentation/screens/splash_screen.dart';

const bool kIsPortable = bool.fromEnvironment('PORTABLE', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(820, 480),
        minimumSize: Size(640, 400),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        title: 'Frame Extractor',
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
    return MaterialApp(
      title: 'Frame Extractor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4F8EF7),
          surface: Color(0xFF13161E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0C10),
      ),
      home: const _InitGate(),
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
