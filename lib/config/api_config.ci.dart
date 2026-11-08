/// OpenRouter API configuration — placeholder committed for CI.
/// Local real key: this file is gitignore-listed; your local copy is never
/// overwritten by git. Copy this file locally and paste your real key in.
/// Get a free key at https://openrouter.ai/keys
class ApiConfig {
  ApiConfig._();

  static const String openRouterApiKey = 'notanapikey';

  /// Free models rotate — check https://openrouter.ai/models?max_price=0
  static const String model = 'nvidia/nemotron-3-ultra-550b-a55b:free';

  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String appName = 'ShelfElf';
}
