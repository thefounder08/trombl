import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai/ai_usage_service.dart';
import 'ai/llm_provider.dart';
import 'ai/providers/proxy_llm_provider.dart';
import 'identity/guest_identity_service.dart';
import 'observability/analytics_repository.dart';

/// The Supabase client (initialised in main()).
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams auth state so the router can react to sign in/out — fires for
/// anonymous (guest) sign-ins exactly the same as registered ones.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// Current user, or null. Synchronous read for guards. Non-null for both
/// guest (anonymous) and registered sessions once `GuestIdentityService`
/// has bootstrapped — see main.dart.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // rebuild on change
  return ref.watch(supabaseProvider).auth.currentUser;
});

/// Wraps Supabase anonymous auth — the guest identity mechanism. See
/// guest_identity_service.dart for why this replaces a locally-generated
/// UUID.
final guestIdentityServiceProvider = Provider<GuestIdentityService>((ref) {
  return GuestIdentityService(ref.watch(supabaseProvider));
});

/// `'guest'` or `'registered'` for the current session — reactive, so UI
/// (e.g. a "sign up to save your progress" banner) can watch it directly.
final userTypeProvider = Provider<String>((ref) {
  ref.watch(currentUserProvider); // rebuild on auth change
  return ref.watch(guestIdentityServiceProvider).userType;
});

/// The single analytics front door — every screen/provider should track
/// through this, never through AnalyticsService/firebase_analytics
/// directly. Created once at boot in main.dart and kept alive for the
/// process lifetime (see analytics_repository.dart for why this is the one
/// deliberate long-lived instance in the analytics stack).
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(guestIdentityServiceProvider));
});

/// Stores the plan share-token a user was viewing when they got sent to login.
/// Cleared by the router redirect after routing to /p/:token.
final pendingPlanTokenProvider = StateProvider<String?>((_) => null);

/// Stores the RSVP status ('in' | 'out') the user intended when they tapped
/// a CTA on /p/:token before being sent to login. Kept alive through setup so
/// the plan landing screen can auto-complete the join after auth.
/// Cleared by PlanLandingScreen after the join succeeds.
final pendingPlanStatusProvider = StateProvider<String?>((_) => null);

/// The LLM, exposed ONLY as the abstract interface.
/// Concrete type (ProxyLlmProvider) is hidden from feature code.
final llmProvider = Provider<LlmProvider>((ref) {
  return ProxyLlmProvider(ref.watch(supabaseProvider));
});

/// Fire-and-forget logger for every Gemini call.
final aiUsageServiceProvider = Provider<AiUsageService>((ref) {
  return AiUsageService(ref.watch(supabaseProvider));
});

/// Optional mood text typed by the user on the home screen.
/// Read by the decide picker to add context to the prompt; cleared after use.
final moodInputProvider = StateProvider<String?>((_) => null);

/// Set to true by home screen before navigating to /decide so the picker
/// auto-starts (skipping the fork phase).
final decideShouldAutoStartProvider = StateProvider<bool>((_) => false);
