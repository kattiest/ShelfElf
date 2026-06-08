/// OpenRouter API configuration.
/// Sign up free (no credit card) at https://openrouter.ai
/// Then go to https://openrouter.ai/keys to generate your API key.
///
/// IMPORTANT: Do not commit this file with a real key.
/// lib/config/api_config.dart is already in .gitignore.
class ApiConfig {
  ApiConfig._();

  /// Your OpenRouter API key — replace this with the key from openrouter.ai/keys
  static const String openRouterApiKey = 'fakeapikey';

  /// The model to use. These are all free on OpenRouter (append :free to the id):
  ///   google/gemma-4-31b-it:free     — Google Gemma 4 31B, great all-rounder
  ///   meta-llama/llama-4-scout:free  — Meta Llama 4, fast
  ///   qwen/qwen3-8b:free             — Alibaba Qwen3, good at instructions
  ///   openrouter/free                — auto-picks a free model for you
  static const String model = 'google/gemma-4-31b-it:free';

  /// OpenRouter API endpoint (OpenAI-compatible)
  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// App name shown in OpenRouter dashboard (optional but polite)
  static const String appName = 'ShelfElf';
}
