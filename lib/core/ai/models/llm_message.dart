/// A single prompt to the LLM. The proxy handles provider specifics.
class LlmRequest {
  const LlmRequest({required this.system, required this.prompt});
  final String system;
  final String prompt;
}
