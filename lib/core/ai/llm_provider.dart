import '../../shared/result.dart';
import 'models/llm_message.dart';

/// The ONLY LLM surface feature code is allowed to touch.
/// Concrete implementations live in providers/ and must never be
/// imported directly by features.
abstract interface class LlmProvider {
  Future<Result<String>> generate(LlmRequest request);
}
