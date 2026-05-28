import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_config.dart';
import '../../../shared/result.dart';
import '../llm_provider.dart';
import '../models/llm_message.dart';

/// The single concrete LLM provider. It calls the Supabase edge function
/// (`llm-proxy`), which holds the API key and decides which model to use.
///
/// Why this instead of the skill's three-SDK setup: the app must never hold
/// a provider key. Switching Gemini/Claude/GPT is a server-side env change,
/// so the client needs exactly one implementation — this one.
class ProxyLlmProvider implements LlmProvider {
  ProxyLlmProvider(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<String>> generate(LlmRequest request) async {
    try {
      final res = await _client.functions.invoke(
        AppConfig.llmProxyFunction,
        body: {'system': request.system, 'prompt': request.prompt},
      );
      final data = res.data;
      if (data is Map && data['text'] is String) {
        return Success(_stripMarkdown(data['text'] as String));
      }
      return const Failure("trom went quiet. try again?");
    } catch (_) {
      return const Failure("that didn't go through. try again?");
    }
  }

  /// Trom speaks plainly — strip stray markdown the model might add.
  String _stripMarkdown(String s) => s
      .replaceAll(RegExp(r'[*_`#>]'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
