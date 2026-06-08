import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/food_item.dart';
import '../providers/inventory_provider.dart';
import '../services/gemini_service.dart';

// ── Chat message model ────────────────────────────────────────────────────────

enum _MessageRole { user, assistant }

class _ChatMessage {
  final _MessageRole role;
  final String text;
  final List<IngredientSuggestion> ingredients;
  final bool isLoading;

  const _ChatMessage({
    required this.role,
    required this.text,
    this.ingredients = const [],
    this.isLoading = false,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();

  final List<_ChatMessage> _messages = [];
  final Set<String> _addedToList = {};

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isThinking = false;
  String _liveTranscript = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    // Welcome message
    _messages.add(const _ChatMessage(
      role: _MessageRole.assistant,
      text: "Hi! I'm Shelf Elf AI 🧝\n\nTell me what you want to cook — "
          "tap the mic or type below — and I'll check your pantry and build "
          "your shopping list.",
    ));
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.cancel();
    super.dispose();
  }

  // ── Voice ──────────────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        if (_liveTranscript.isNotEmpty) {
          _controller.text = _liveTranscript;
          _liveTranscript = '';
        }
      });
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _controller.clear();
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _liveTranscript = result.recognizedWords;
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
        // Auto-send when speech is final
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _speech.stop();
          setState(() => _isListening = false);
          Future.delayed(const Duration(milliseconds: 300), _sendMessage);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isThinking) return;

    _controller.clear();
    setState(() {
      _liveTranscript = '';
      _messages.add(_ChatMessage(role: _MessageRole.user, text: text));
      _messages.add(const _ChatMessage(
        role: _MessageRole.assistant,
        text: '',
        isLoading: true,
      ));
      _isThinking = true;
    });
    _scrollToBottom();

    final inventory = context.read<InventoryProvider>().items.toList();

    try {
      final response = await GeminiService.instance.askAboutMeal(
        userMessage: text,
        inventory: inventory,
      );

      if (!mounted) return;
      setState(() {
        _messages.removeLast(); // remove loading bubble
        _messages.add(_ChatMessage(
          role: _MessageRole.assistant,
          text: response.rawText,
          ingredients: response.ingredients,
        ));
        _isThinking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(_ChatMessage(
          role: _MessageRole.assistant,
          text: '⚠️ Something went wrong: ${e.toString()}\n\n'
              'Make sure your Gemini API key is set in '
              '`lib/config/api_config.dart`.',
        ));
        _isThinking = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Add ingredient to shopping list ───────────────────────────────────────

  void _addToShoppingList(IngredientSuggestion ingredient) {
    if (_addedToList.contains(ingredient.name)) return;

    final provider = context.read<InventoryProvider>();
    final newItem = FoodItem(
      upc: '',
      product: ingredient.name,
      packageSize: 0,
      servingSize: 0,
      sellByDate: '',
      percentUsed: 100, // mark as fully used / need to buy
      location: 'Shopping List',
      orderingLevel: 100, // always show in shopping list
    );
    provider.addItem(newItem);

    setState(() => _addedToList.add(ingredient.name));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ingredient.name} added to shopping list'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Shelf Elf AI'),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear chat',
              onPressed: () => setState(() {
                _messages.clear();
                _addedToList.clear();
                _messages.add(const _ChatMessage(
                  role: _MessageRole.assistant,
                  text: "Chat cleared. What do you want to cook?",
                ));
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) =>
                  _buildBubble(_messages[i], cs),
            ),
          ),

          // ── Live transcript banner ────────────────────────────────────────
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.mic, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _liveTranscript.isNotEmpty
                          ? _liveTranscript
                          : 'Listening…',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontStyle: _liveTranscript.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Input bar ────────────────────────────────────────────────────
          _buildInputBar(cs),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg, ColorScheme cs) {
    final isUser = msg.role == _MessageRole.user;

    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text('Thinking…',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message text
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: isUser
                  ? Text(
                      msg.text,
                      style: TextStyle(color: cs.onPrimary, fontSize: 15),
                    )
                  : MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                            color: cs.onSurface, fontSize: 15, height: 1.4),
                        strong: TextStyle(
                            color: cs.onSurface, fontWeight: FontWeight.bold),
                        code: TextStyle(
                          backgroundColor: cs.surfaceContainerHighest,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),

            // Ingredient chips
            if (msg.ingredients.isNotEmpty)
              _buildIngredientChips(msg.ingredients, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientChips(
      List<IngredientSuggestion> ingredients, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Text(
            'TAP TO ADD TO SHOPPING LIST',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ingredients.map((ing) {
              final added = _addedToList.contains(ing.name);
              final needToBuy = !ing.inInventory || ing.isLow;

              Color chipColor;
              Color textColor;
              IconData icon;

              if (added) {
                chipColor = cs.secondaryContainer;
                textColor = cs.onSecondaryContainer;
                icon = Icons.check_circle;
              } else if (!ing.inInventory) {
                chipColor = cs.errorContainer;
                textColor = cs.onErrorContainer;
                icon = Icons.add_shopping_cart;
              } else if (ing.isLow) {
                chipColor = Colors.orange.shade100;
                textColor = Colors.orange.shade900;
                icon = Icons.warning_amber_rounded;
              } else {
                chipColor = Colors.green.shade100;
                textColor = Colors.green.shade900;
                icon = Icons.check_circle_outline;
              }

              return GestureDetector(
                onTap: needToBuy && !added
                    ? () => _addToShoppingList(ing)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: added ? cs.secondary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: textColor),
                      const SizedBox(width: 5),
                      Text(
                        ing.quantity != null
                            ? '${ing.name} (${ing.quantity})'
                            : ing.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: added
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mic button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isListening ? cs.error : cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  color: _isListening ? cs.onError : cs.onPrimaryContainer,
                ),
                tooltip: _speechAvailable
                    ? (_isListening ? 'Stop listening' : 'Speak')
                    : 'Speech not available',
                onPressed: _speechAvailable ? _toggleListening : null,
              ),
            ),
            const SizedBox(width: 8),

            // Text input
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'What do you want to cook?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isThinking ? cs.surfaceContainerHigh : cs.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isThinking
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Icon(Icons.send, color: cs.onPrimary),
                onPressed: _isThinking ? null : _sendMessage,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
