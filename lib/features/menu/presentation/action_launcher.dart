import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/action_engine.dart';

/// Executes [ActionResult] values produced by [ActionEngine].
///
/// Responsibilities:
///   - Launch external URLs via url_launcher (primary + fallback).
///   - Show Trombl-voice snackbars for failures and coming-soon.
///
/// Navigation (GoRouter) stays in the caller — this class is BuildContext-aware
/// only to show snackbars.
abstract final class ActionLauncher {
  /// Try to open [url]. If it fails and [fallbackUrl] is provided, try that.
  /// If both fail, show a snackbar. Returns true if any URL was launched.
  static Future<bool> launchExternal(
    String url, {
    String? fallbackUrl,
    required BuildContext context,
  }) async {
    if (await _tryLaunch(url)) return true;
    if (fallbackUrl != null && await _tryLaunch(fallbackUrl)) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "couldn't open that. try again?",
            style: TextStyle(fontFamily: 'DMSans'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  /// Show the "coming soon" snackbar. Call this when dispatching
  /// [ComingSoonAction] in the UI layer.
  static void showComingSoon(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'soon. working on it.',
          style: TextStyle(fontFamily: 'DMSans'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show the [FailedAction.message] as a snackbar.
  static void showFailed(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'DMSans'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<bool> _tryLaunch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
