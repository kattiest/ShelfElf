import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food_item.dart';

/// A single ingredient suggestion returned by the AI.
class IngredientSuggestion {
  final String name;
  final String? quantity; // e.g. "2 cups", "500g"
  final bool inInventory; // true if user already has it
  final bool isLow; // true if in inventory but running low

  const IngredientSuggestion({
    required this.name,
    this.quantity,
    required this.inInventory,
    required this.isLow,
  });
}

/// Response from the AI for a meal query.
class GeminiMealResponse {
  final String mealName;
  final String rawText; // full markdown response for display
  final List<IngredientSuggestion> ingredients;

  const GeminiMealResponse({
    required this.mealName,
    required this.rawText,
    required this.ingredients,
  });
}

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  static const _headers = {
    'Content-Type': 'application/json',
    'HTTP-Referer': 'https://github.com/pantrypal',
    'X-Title': ApiConfig.appName,
  };

  Map<String, String> get _authHeaders => {
        ..._headers,
        'Authorization': 'Bearer ${ApiConfig.openRouterApiKey}',
      };

  /// Send a chat request to OpenRouter and return the assistant reply text.
  Future<String> _complete(List<Map<String, String>> messages) async {
    final body = jsonEncode({
      'model': ApiConfig.model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1024,
    });

    final response = await http
        .post(
          Uri.parse(ApiConfig.baseUrl),
          headers: _authHeaders,
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? response.body;
      throw Exception('OpenRouter error ${response.statusCode}: $msg');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'] as String? ??
        'No response.';
  }

  /// Ask the AI what ingredients are needed for [userMessage] (e.g. "I want to
  /// make lasagna") given the current [inventory].
  Future<GeminiMealResponse> askAboutMeal({
    required String userMessage,
    required List<FoodItem> inventory,
  }) async {
    final inventorySummary = inventory.isEmpty
        ? 'The user currently has no items in their pantry.'
        : inventory.map((item) {
            final status = item.isLow
                ? 'LOW (${item.percentRemaining}% remaining)'
                : '${item.percentRemaining}% remaining';
            return '- ${item.product}: $status';
          }).join('\n');

    final systemPrompt = '''
You are PantryPal, a friendly kitchen and pantry assistant built into a food inventory app.
The user's current pantry inventory:
$inventorySummary

When the user asks about making a meal, list ALL ingredients needed.
For each ingredient use EXACTLY this format (one per line):
INGREDIENT: <name> | QTY: <quantity> | STATUS: <HAS/LOW/NEED>

Status values:
- HAS = user has enough in inventory
- LOW = user has it but it is running low (below 30% remaining)
- NEED = user does not have it

After the ingredient list, add a short friendly summary (2-3 sentences max).
Keep your total response concise and practical.
''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ];

    final rawText = await _complete(messages);
    final ingredients = _parseIngredients(rawText, inventory);
    final mealName = _extractMealName(userMessage);

    return GeminiMealResponse(
      mealName: mealName,
      rawText: rawText,
      ingredients: ingredients,
    );
  }

  /// General follow-up chat with conversation history.
  Future<String> chat({
    required String userMessage,
    required List<FoodItem> inventory,
    List<Map<String, String>> history = const [],
  }) async {
    final inventorySummary = inventory.isEmpty
        ? 'No items in pantry.'
        : inventory
            .map((i) => '- ${i.product} (${i.percentRemaining}% left)')
            .join('\n');

    final systemPrompt = '''
You are PantryPal, a friendly kitchen and pantry assistant.
The user's current inventory:
$inventorySummary
Keep responses concise and practical.
''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    return _complete(messages);
  }

  // ── Parsing helpers ────────────────────────────────────────────────────────

  List<IngredientSuggestion> _parseIngredients(
      String text, List<FoodItem> inventory) {
    final results = <IngredientSuggestion>[];

    for (final line in text.split('\n')) {
      if (!line.contains('INGREDIENT:')) continue;

      try {
        final parts = line.split('|');
        if (parts.length < 3) continue;

        final name = parts[0]
            .replaceAll('INGREDIENT:', '')
            .replaceAll('*', '')
            .trim();
        final qty = parts[1].replaceAll('QTY:', '').trim();
        final statusStr =
            parts[2].replaceAll('STATUS:', '').trim().toUpperCase();

        if (name.isEmpty) continue;

        bool inInventory = false;
        bool isLow = false;

        if (statusStr.contains('HAS')) {
          inInventory = true;
        } else if (statusStr.contains('LOW')) {
          inInventory = true;
          isLow = true;
        } else {
          // NEED — do a fuzzy check anyway in case the AI got it wrong
          inInventory = _fuzzyMatch(name, inventory);
        }

        results.add(IngredientSuggestion(
          name: name,
          quantity: qty.isNotEmpty && qty != '-' ? qty : null,
          inInventory: inInventory,
          isLow: isLow,
        ));
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  bool _fuzzyMatch(String ingredientName, List<FoodItem> inventory) {
    final lower = ingredientName.toLowerCase();
    return inventory.any((item) {
      final itemLower = item.product.toLowerCase();
      return itemLower.contains(lower) || lower.contains(itemLower);
    });
  }

  String _extractMealName(String message) {
    final cleaned = message
        .toLowerCase()
        .replaceAll(
            RegExp(
                r"i want to make|i'd like to make|how do i make|"
                r"recipe for|make me|can i make|i wanna make"),
            '')
        .trim();
    if (cleaned.isEmpty) return message;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}
