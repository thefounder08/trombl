import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai/llm_provider.dart';
import 'ai/providers/proxy_llm_provider.dart';

/// The Supabase client (initialised in main()).
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams auth state so the router can react to sign in/out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// Current user, or null. Synchronous read for guards.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // rebuild on change
  return ref.watch(supabaseProvider).auth.currentUser;
});

/// Stores the plan share-token a user was viewing when they got sent to login.
/// Cleared once the post-login navigation back to the plan has been triggered.
final pendingPlanTokenProvider = StateProvider<String?>((_) => null);

/// The LLM, exposed ONLY as the abstract interface.
/// Concrete type (ProxyLlmProvider) is hidden from feature code.
final llmProvider = Provider<LlmProvider>((ref) {
  return ProxyLlmProvider(ref.watch(supabaseProvider));
});
