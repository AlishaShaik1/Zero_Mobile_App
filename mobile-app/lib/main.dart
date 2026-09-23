import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/live_overlay_widget.dart';
import 'screens/live_voice_screen.dart' as screens_live;
import 'screens/ring_companion_screen.dart';
import 'screens/ring_camera_screen.dart';
import 'services/ring_ble_service.dart';
import 'services/ring_audio_pipeline.dart';
import 'theme/zero_theme.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter'),
      home: const LiveOverlayWidget(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const platformChannel = MethodChannel('com.example.zero_air/tools');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://zvgstbouzswbobenezij.supabase.co',
      ),
      publishableKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2Z3N0Ym91enN3Ym9iZW5lemlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODM1NzMsImV4cCI6MjEwMDY1OTU3M30.TSqVQZuNAmHOvFJPZzwinVaQW4ObVeJgS2cggPj2FKE',
      ),
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Supabase init skipped/error: $e');
  }

  try {
    FlutterForegroundTask.initCommunicationPort();
  } catch (e) {
    debugPrint('ForegroundTask init error: $e');
  }

  try {
    await RingBleService.instance.initialize();
    await RingAudioPipeline.instance.initialize();
  } catch (e) {
    debugPrint('RingBleService / RingAudioPipeline init error: $e');
  }

  platformChannel.setMethodCallHandler((call) async {
    if (call.method == 'wake_live_voice') {
      navigatorKey.currentState?.pushNamed('/live_voice');
    }
  });

  runApp(const ZeroAirApp());
}

class ZeroAirApp extends StatelessWidget {
  const ZeroAirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero Air',
      navigatorKey: navigatorKey,
      theme: ZeroTheme.lightTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      builder: (context, child) => WithForegroundTask(
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {
        '/': (context) => const SplashScreen(),
        '/live_voice': (context) => const screens_live.LiveVoiceScreen(),
        '/ring_companion': (context) => const RingCompanionScreen(),
        '/ring_camera': (context) => const RingCameraScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
