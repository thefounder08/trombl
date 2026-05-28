import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/trombl_theme.dart';

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

  runApp(const ProviderScope(child: TromblApp()));
}

class TromblApp extends ConsumerWidget {
  const TromblApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0B0D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              "missing config.\nrun with --dart-define=SUPABASE_URL=... and SUPABASE_ANON_KEY=...",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
