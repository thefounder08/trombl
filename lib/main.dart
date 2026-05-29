import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/trombl_theme.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Init notification service (no permission prompt yet — just primes the channel).
  await NotificationService().init();

  runApp(const ProviderScope(child: TromblApp()));
}

class TromblApp extends ConsumerStatefulWidget {
  const TromblApp({super.key});

  @override
  ConsumerState<TromblApp> createState() => _TromblAppState();
}

class _TromblAppState extends ConsumerState<TromblApp> {
  @override
  void initState() {
    super.initState();
    // Schedule notifications once Supabase auth is ready
    _maybeScheduleNotifications();
  }

  void _maybeScheduleNotifications() {
    // Listen for first sign-in and schedule daily reminders
    final client = Supabase.instance.client;
    client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        // Request permission + schedule — fire and forget, never block UI
        NotificationService()
            .requestPermission()
            .then((granted) {
              if (granted) return NotificationService().scheduleDailyReminders();
            })
            .catchError((_) {}); // permission or scheduling failure is non-fatal
      } else if (event.event == AuthChangeEvent.signedOut) {
        NotificationService().cancelAll().catchError((_) {});
      }
    });

    // If already signed in (app cold start with existing session)
    if (client.auth.currentUser != null) {
      NotificationService()
          .requestPermission()
          .then((granted) {
            if (granted) return NotificationService().scheduleDailyReminders();
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'trombl',
      debugShowCheckedModeBanner: false,
      theme: TromblTheme.dark,
      routerConfig: router,
    );
  }
}

/// Shown when the app is built without Supabase env vars.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: TromblColors.bg,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "missing config.\nrun with --dart-define=SUPABASE_URL=... and SUPABASE_ANON_KEY=...",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TromblColors.textSub,
                fontFamily: TromblText.sans,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
