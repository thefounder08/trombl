import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/services/pending_join_service.dart';
import 'core/theme/trombl_theme.dart';
import 'core/notifications/notification_service.dart';
import 'core/observability/analytics_service.dart';
import 'core/observability/crash_service.dart';

Future<void> main() async {
  // Use path-based URLs on web (/p/token) instead of hash-based (#/login).
  if (kIsWeb) usePathUrlStrategy();
  // Wrap everything in a zone so unhandled async errors are captured.
  await runZonedGuarded(
    _boot,
    CrashService.onAsyncError,
  );
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Firebase init — mobile only. There's no web Firebase config
  // (firebase_options.dart / JS SDK setup) yet, and firebase_crashlytics
  // doesn't support web at all, so Firebase.initializeApp() throws inside
  // the JS interop layer on web in a way that escapes this try/catch.
  // CrashService + AnalyticsService gracefully no-op until this succeeds.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      CrashService.init();
      AnalyticsService.init();
    } catch (e) {
      debugPrint('[Firebase] init skipped (no config files yet): $e');
    }

    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('[Notification] init skipped: $e');
    }
  }

  // Load any pending plan-join intent from SharedPreferences so it survives
  // a magic-link deep-link restart on mobile.
  final pendingJoin = await PendingJoinService.load();

  runApp(ProviderScope(
    overrides: pendingJoin != null
        ? [
            pendingPlanTokenProvider
                .overrideWith((ref) => pendingJoin.token),
            pendingPlanStatusProvider
                .overrideWith((ref) => pendingJoin.status),
          ]
        : const [],
    child: const TromblApp(),
  ));
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
    _listenAuth();
  }

  void _listenAuth() {
    final client = Supabase.instance.client;

    // Handle sign-in: identify user in crash/analytics, register FCM token.
    client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        final uid = event.session?.user.id;
        if (uid != null) {
          CrashService.setUser(uid);
          AnalyticsService.setUser(uid);
        }
        NotificationService()
            .requestPermission()
            .then((granted) async {
              if (granted) {
                AnalyticsService.notificationPermissionGranted();
              }
              if (!granted) return;
              await NotificationService().registerToken();
              await NotificationService().scheduleDailyReminders();
            })
            .catchError((_) {});
      } else if (event.event == AuthChangeEvent.signedOut) {
        CrashService.clearUser();
        AnalyticsService.clearUser();
        NotificationService().unregisterTokens().catchError((_) {});
        NotificationService().cancelAll().catchError((_) {});
      }
    });

    // Cold start — already signed in.
    final current = client.auth.currentUser;
    if (current != null) {
      CrashService.setUser(current.id);
      AnalyticsService.setUser(current.id);
      NotificationService()
          .requestPermission()
          .then((granted) async {
            if (!granted) return;
            await NotificationService().registerToken();
            await NotificationService().scheduleDailyReminders();
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
